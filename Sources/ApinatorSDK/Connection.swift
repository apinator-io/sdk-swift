import Foundation

public class Connection: NSObject {
    private var ws: URLSessionWebSocketTask?
    private var session: URLSession?
    private(set) var state: ConnectionState = .initialized
    private let options: RealtimeOptions
    private var onMessage: ((Message) -> Void)?
    private var onStateChange: ((ConnectionState, ConnectionState) -> Void)?
    private var reconnectAttempts = 0
    private var reconnectTimer: Timer?
    private var activityTimer: Timer?
    private var pongTimer: Timer?
    private(set) var socketId: String?

    init(
        options: RealtimeOptions,
        onMessage: @escaping (Message) -> Void,
        onStateChange: @escaping (ConnectionState, ConnectionState) -> Void
    ) {
        self.options = options
        self.onMessage = onMessage
        self.onStateChange = onStateChange
        super.init()
    }

    func connect() {
        guard state == .initialized || state == .disconnected || state == .unavailable else {
            return
        }

        clearTimers()
        setState(.connecting)

        let host = resolveWSHost()
        let urlString = "\(host)/app/\(options.appKey)?protocol=7&client=swift&version=1.0.0"

        guard let url = URL(string: urlString) else {
            setState(.unavailable)
            return
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session

        let ws = session.webSocketTask(with: url)
        self.ws = ws
        ws.resume()

        receiveMessage()
    }

    func disconnect() {
        clearTimers()
        reconnectAttempts = 0
        setState(.disconnected)
        ws?.cancel(with: .normalClosure, reason: nil)
        ws = nil
        session?.invalidateAndCancel()
        session = nil
        socketId = nil
    }

    func send(_ message: Message) {
        guard state == .connected else {
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            guard let string = String(data: data, encoding: .utf8) else {
                return
            }

            let wsMessage = URLSessionWebSocketTask.Message.string(string)
            ws?.send(wsMessage) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("Failed to encode message: \(error)")
        }
    }

    private func receiveMessage() {
        ws?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let wsMessage):
                switch wsMessage {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let message = try? JSONDecoder().decode(Message.self, from: data) {
                        self.handleMessage(message)
                    }
                case .data(let data):
                    if let message = try? JSONDecoder().decode(Message.self, from: data) {
                        self.handleMessage(message)
                    }
                @unknown default:
                    break
                }

                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: Message) {
        switch message.event {
        case "realtime:connection_established":
            if let data = message.data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.socketId = json["socket_id"] as? String

                if let timeoutSeconds = json["activity_timeout"] as? TimeInterval {
                    resetActivityTimer(timeout: timeoutSeconds)
                } else {
                    resetActivityTimer(timeout: options.activityTimeout)
                }

                reconnectAttempts = 0
                setState(.connected)
            }

        case "realtime:pong":
            // Reset pong timer
            pongTimer?.invalidate()
            pongTimer = nil

        case "realtime:error":
            if let data = message.data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["code"] as? Int {
                // Fatal errors: 4000-4004
                if code >= 4000 && code <= 4004 {
                    disconnect()
                    return
                }
            }

        default:
            break
        }

        // Forward all messages to callback
        onMessage?(message)
    }

    private func handleDisconnect() {
        clearTimers()
        ws = nil
        socketId = nil

        guard options.enableReconnect && reconnectAttempts < options.maxReconnectAttempts else {
            setState(.unavailable)
            return
        }

        setState(.disconnected)

        // Exponential backoff: min(1000 * 2^attempt, 30000) ms
        let delay = min(1.0 * pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }

    private func resetActivityTimer(timeout: TimeInterval) {
        activityTimer?.invalidate()

        activityTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Send ping
            let pingMessage = Message(event: "realtime:ping", channel: nil, data: "{}")
            self.send(pingMessage)

            // Set pong timeout (30 seconds)
            self.pongTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                // No pong received, close connection
                self.ws?.cancel(with: .goingAway, reason: nil)
                self.handleDisconnect()
            }
        }
    }

    private func resolveWSHost() -> String {
        return "wss://ws-\(options.cluster).apinator.io"
    }

    private func setState(_ newState: ConnectionState) {
        let prev = state
        state = newState
        if prev != newState {
            onStateChange?(prev, newState)
        }
    }

    private func clearTimers() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        activityTimer?.invalidate()
        activityTimer = nil
        pongTimer?.invalidate()
        pongTimer = nil
    }
}

extension Connection: URLSessionWebSocketDelegate {
    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        // Connection opened, waiting for connection_established message
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        handleDisconnect()
    }
}
