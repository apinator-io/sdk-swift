import Foundation

/// A single WebSocket connection attempt. `Connection` creates a new transport
/// for every attempt and discards it on close, so implementations never need
/// to support reopening.
protocol WebSocketTransport: AnyObject {
    /// Opens the socket. `onText` is called for every text frame and `onClose`
    /// exactly once when the socket closes or fails, on any thread.
    func start(onText: @escaping (String) -> Void, onClose: @escaping () -> Void)
    func send(_ text: String)
    /// Closes the socket and releases its resources. Does not call `onClose`.
    func close()
}

/// `URLSessionWebSocketTask`-backed transport with one `URLSession` per socket,
/// invalidated on close so the session (which retains its delegate) is freed.
final class URLSessionTransport: NSObject, WebSocketTransport, URLSessionWebSocketDelegate {
    private let url: URL
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var onText: ((String) -> Void)?
    private var onClose: (() -> Void)?
    private let lock = NSLock()
    private var finished = false

    init(url: URL) {
        self.url = url
    }

    func start(onText: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        lock.lock()
        self.onText = onText
        self.onClose = onClose
        self.session = session
        self.task = task
        lock.unlock()
        task.resume()
        receive(task)
    }

    func send(_ text: String) {
        lock.lock()
        let task = finished ? nil : self.task
        lock.unlock()
        task?.send(.string(text)) { _ in
            // A failed send surfaces as a receive failure, which closes the socket.
        }
    }

    func close() {
        lock.lock()
        let task = self.task
        lock.unlock()
        guard let (session, _) = finish() else { return }
        task?.cancel(with: .normalClosure, reason: nil)
        session?.invalidateAndCancel()
    }

    private func receive(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(.string(let text)):
                self.deliver(text)
                self.receive(task)
            case .success(.data(let data)):
                if let text = String(data: data, encoding: .utf8) {
                    self.deliver(text)
                }
                self.receive(task)
            case .success:
                self.receive(task)
            case .failure:
                self.fail()
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        fail()
    }

    private func deliver(_ text: String) {
        lock.lock()
        let onText = finished ? nil : self.onText
        lock.unlock()
        onText?(text)
    }

    private func fail() {
        guard let (session, onClose) = finish() else { return }
        session?.invalidateAndCancel()
        onClose?()
    }

    /// Marks the transport finished and hands back what needs tearing down.
    /// Returns nil if it already finished, so teardown happens exactly once.
    private func finish() -> (URLSession?, (() -> Void)?)? {
        lock.lock()
        defer { lock.unlock() }
        if finished { return nil }
        finished = true
        let result = (session, onClose)
        onText = nil
        onClose = nil
        session = nil
        return result
    }
}
