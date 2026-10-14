import Foundation

/// WebSocket lifecycle: connect, keep-alive, and reconnect.
///
/// All mutable state lives on a private serial queue and every timer is a GCD
/// timer on that queue, so nothing depends on a run loop: URLSession delivers
/// callbacks on background threads, where `Timer.scheduledTimer` never fires.
/// `onMessage` and `onStateChange` are called on that queue.
public class Connection: NSObject {
    private static let defaultActivityTimeout: TimeInterval = 120
    private static let maxReconnectDelay: TimeInterval = 30

    private let queue = DispatchQueue(label: "io.apinator.connection")
    private let queueKey = DispatchSpecificKey<Void>()

    private var transport: WebSocketTransport?
    private var _state: ConnectionState = .initialized
    private var _socketId: String?
    private let options: RealtimeOptions
    private let makeTransport: (URL) -> WebSocketTransport
    private var onMessage: ((Message) -> Void)?
    private var onStateChange: ((ConnectionState, ConnectionState) -> Void)?
    private var reconnectAttempts = 0
    private var activityTimeout = Connection.defaultActivityTimeout
    private var reconnectTimer: DispatchWorkItem?
    private var activityTimer: DispatchWorkItem?
    private var pongTimer: DispatchWorkItem?

    /// Base delay before the first reconnect attempt; lowered by tests.
    var reconnectBaseDelay: TimeInterval = 1

    var state: ConnectionState { onQueue { _state } }
    var socketId: String? { onQueue { _socketId } }

    convenience init(
        options: RealtimeOptions,
        onMessage: @escaping (Message) -> Void,
        onStateChange: @escaping (ConnectionState, ConnectionState) -> Void
    ) {
        self.init(
            options: options,
            onMessage: onMessage,
            onStateChange: onStateChange,
            makeTransport: { URLSessionTransport(url: $0) }
        )
    }

    init(
        options: RealtimeOptions,
        onMessage: @escaping (Message) -> Void,
        onStateChange: @escaping (ConnectionState, ConnectionState) -> Void,
        makeTransport: @escaping (URL) -> WebSocketTransport
    ) {
        self.options = options
        self.onMessage = onMessage
        self.onStateChange = onStateChange
        self.makeTransport = makeTransport
        super.init()
        queue.setSpecific(key: queueKey, value: ())
    }

    func connect() {
        onQueue { self.openSocket() }
    }

    func disconnect() {
        onQueue {
            self.clearTimers()
            self.reconnectAttempts = 0
            self.setState(.disconnected)
            self.closeSocket()
        }
    }

    func send(_ message: Message) {
        onQueue {
            guard self._state == .connected else { return }
            self.write(message)
        }
    }

    // MARK: - Queue-confined internals

    /// Runs `work` on the connection queue, inline if already on it (callbacks
    /// re-enter, e.g. resubscribing from inside `onStateChange`).
    private func onQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return work()
        }
        return queue.sync(execute: work)
    }

    private func openSocket() {
        // A socket is already open or opening.
        guard transport == nil else { return }

        // An explicit connect() while a reconnect is pending connects right away.
        reconnectTimer?.cancel()
        reconnectTimer = nil

        if let problem = optionsProblem(options) {
            // Can never connect; a missing cluster would retry an unreachable host forever.
            print("[apinator] \(problem)")
            setState(.unavailable)
            return
        }

        let host = resolveWSHost()
        guard let url = URL(string: "\(host)/app/\(options.appKey)?protocol=7&client=swift&version=1.0.0") else {
            setState(.unavailable)
            return
        }

        setState(.connecting)

        let transport = makeTransport(url)
        self.transport = transport
        // Callbacks from a socket that has since been replaced are ignored, so a
        // late close from an old socket can't tear down the current one.
        transport.start(
            onText: { [weak self, weak transport] text in
                self?.queue.async {
                    guard let self = self, let transport = transport, self.transport === transport else { return }
                    self.handleText(text)
                }
            },
            onClose: { [weak self, weak transport] code in
                self?.queue.async {
                    guard let self = self, let transport = transport, self.transport === transport else { return }
                    if let code = code, isFatalCode(code) {
                        // Refused for good (invalid key, app disabled, wrong cluster);
                        // reconnecting would fail the same way forever.
                        self.disconnect()
                        return
                    }
                    self.handleDisconnect()
                }
            }
        )
    }

    private func closeSocket() {
        let transport = self.transport
        self.transport = nil
        _socketId = nil
        transport?.close()
    }

    private func write(_ message: Message) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        transport?.send(text)
    }

    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Message.self, from: data) else {
            return // Ignore malformed messages
        }
        // Any traffic from the server proves the connection is alive.
        resetActivityTimer()
        handleMessage(message)
    }

    private func handleMessage(_ message: Message) {
        switch message.event {
        case "realtime:connection_established":
            guard let data = message.data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                break
            }
            _socketId = json["socket_id"] as? String
            activityTimeout = positive(options.activityTimeout)
                ?? positive(json["activity_timeout"] as? TimeInterval)
                ?? Connection.defaultActivityTimeout
            reconnectAttempts = 0
            setState(.connected)
            resetActivityTimer()

        case "realtime:error":
            if let data = message.data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["code"] as? Int,
               isFatalCode(code) {
                // The server says why (e.g. an app ID used as the key, or the wrong
                // cluster). Surface it, let the app see it, then stop for good.
                print("[apinator] \(json["message"] as? String ?? "connection refused") (code \(code))")
                onMessage?(message)
                disconnect()
                return
            }

        default:
            break
        }

        onMessage?(message)
    }

    private func handleDisconnect() {
        clearTimers()
        closeSocket()

        if _state == .disconnected { return }

        guard options.enableReconnect && reconnectAttempts < options.maxReconnectAttempts else {
            setState(.unavailable)
            return
        }

        setState(.connecting)
        let backoff = min(reconnectBaseDelay * pow(2.0, Double(reconnectAttempts)), Connection.maxReconnectDelay)
        // Jitter (50–100% of the backoff) so clients dropped together by a server
        // restart don't all reconnect in the same instant.
        let delay = backoff * Double.random(in: 0.5...1.0)
        reconnectAttempts += 1

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.reconnectTimer = nil
            self.openSocket()
        }
        reconnectTimer = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// (Re)starts the idle timer. When it fires the client pings and waits up to
    /// `pongTimeout` for any server message before dropping the socket.
    private func resetActivityTimer() {
        guard _state == .connected || _state == .connecting else { return }
        activityTimer?.cancel()
        pongTimer?.cancel()
        pongTimer = nil

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.activityTimer = nil
            self.write(Message(event: "realtime:ping", channel: nil, data: "{}"))

            let pong = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.pongTimer = nil
                // No reply: drop the socket and reconnect now rather than wait
                // for a dead network to report the close.
                self.handleDisconnect()
            }
            self.pongTimer = pong
            let pongTimeout = positive(self.options.pongTimeout) ?? 30
            self.queue.asyncAfter(deadline: .now() + pongTimeout, execute: pong)
        }
        activityTimer = work
        queue.asyncAfter(deadline: .now() + activityTimeout, execute: work)
    }

    private func resolveWSHost() -> String {
        return "wss://ws-\(options.cluster).apinator.io"
    }

    private func setState(_ newState: ConnectionState) {
        let prev = _state
        _state = newState
        if prev != newState {
            onStateChange?(prev, newState)
        }
    }

    private func clearTimers() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
        activityTimer?.cancel()
        activityTimer = nil
        pongTimer?.cancel()
        pongTimer = nil
    }
}

/// Codes 4000-4099 mean the server refused the connection for a reason retrying
/// cannot fix (invalid app key, app disabled, wrong cluster).
func isFatalCode(_ code: Int) -> Bool {
    return code >= 4000 && code < 4100
}

/// Describes options that can never connect, or nil if they look usable.
func optionsProblem(_ options: RealtimeOptions) -> String? {
    let unset: (String) -> Bool = { ["", "undefined", "null"].contains($0.trimmingCharacters(in: .whitespaces)) }
    if unset(options.appKey) {
        return "appKey is \"\(options.appKey)\". Pass the app key from your app's API keys in the console (it starts with \"app_\")."
    }
    if unset(options.cluster) {
        return "cluster is \"\(options.cluster)\". Set it to the region your app was created in, e.g. \"eu\" or \"us\"."
    }
    return nil
}

/// Returns `value` if it is a positive finite number, otherwise nil.
private func positive(_ value: TimeInterval?) -> TimeInterval? {
    guard let value = value, value.isFinite, value > 0 else { return nil }
    return value
}
