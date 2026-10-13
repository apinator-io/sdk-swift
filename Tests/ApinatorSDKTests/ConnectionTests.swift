import XCTest
@testable import ApinatorSDK

final class ConnectionTests: XCTestCase {
    func testInitialState() {
        let options = RealtimeOptions(appKey: "test-key", cluster: "eu")
        let connection = Connection(
            options: options,
            onMessage: { _ in },
            onStateChange: { _, _ in }
        )

        XCTAssertEqual(connection.state, .initialized)
        XCTAssertNil(connection.socketId)
    }

    func testStateTransitions() {
        let stateChangeExpectation = XCTestExpectation(description: "State change callback")
        var receivedStates: [(ConnectionState, ConnectionState)] = []

        let options = RealtimeOptions(appKey: "test-key", cluster: "eu")
        let connection = Connection(
            options: options,
            onMessage: { _ in },
            onStateChange: { prev, curr in
                receivedStates.append((prev, curr))
                if curr == .connecting {
                    stateChangeExpectation.fulfill()
                }
            }
        )

        // Connect should transition to connecting
        connection.connect()

        wait(for: [stateChangeExpectation], timeout: 2.0)
        XCTAssertEqual(receivedStates.first?.0, .initialized)
        XCTAssertEqual(receivedStates.first?.1, .connecting)
    }

    func testDisconnect() {
        let options = RealtimeOptions(appKey: "test-key", cluster: "eu")
        let connection = Connection(
            options: options,
            onMessage: { _ in },
            onStateChange: { _, _ in }
        )

        connection.connect()
        connection.disconnect()

        XCTAssertEqual(connection.state, .disconnected)
        XCTAssertNil(connection.socketId)
    }

    func testMessageSending_notConnectedDoesNotCrash() {
        let options = RealtimeOptions(appKey: "test-key", cluster: "eu")
        let connection = Connection(
            options: options,
            onMessage: { _ in },
            onStateChange: { _, _ in }
        )

        let message = Message(event: "test", channel: nil, data: "{}")

        // Should not crash when not connected
        XCTAssertNoThrow(connection.send(message))
    }

    func testOptionsConfiguration() {
        let options = RealtimeOptions(
            appKey: "test-key",
            cluster: "eu",
            authEndpoint: "https://example.com/auth",
            authHeaders: ["Authorization": "Bearer token"],
            activityTimeout: 60,
            enableReconnect: false,
            maxReconnectAttempts: 3
        )

        XCTAssertEqual(options.appKey, "test-key")
        XCTAssertEqual(options.cluster, "eu")
        XCTAssertEqual(options.authEndpoint, "https://example.com/auth")
        XCTAssertEqual(options.authHeaders?["Authorization"], "Bearer token")
        XCTAssertEqual(options.activityTimeout, 60)
        XCTAssertEqual(options.pongTimeout, 30)
        XCTAssertFalse(options.enableReconnect)
        XCTAssertEqual(options.maxReconnectAttempts, 3)
    }
}

// MARK: - Lifecycle tests against a mock transport

final class MockTransport: WebSocketTransport {
    private(set) var sent: [String] = []
    private(set) var closed = false
    private var onText: ((String) -> Void)?
    private var onClose: (() -> Void)?
    private let lock = NSLock()

    func start(onText: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.onText = onText
        self.onClose = onClose
    }

    func send(_ text: String) {
        lock.lock(); sent.append(text); lock.unlock()
    }

    func close() {
        closed = true
    }

    var sentEvents: [String] {
        lock.lock(); defer { lock.unlock() }
        return sent.compactMap { text in
            (try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])?["event"] as? String
        }
    }

    func receive(event: String, data: String = "{}") {
        let payload: [String: Any] = ["event": event, "data": data]
        let json = try! JSONSerialization.data(withJSONObject: payload)
        onText?(String(data: json, encoding: .utf8)!)
    }

    func established(activityTimeout: Double = 120) {
        receive(
            event: "realtime:connection_established",
            data: "{\"socket_id\":\"1.\(Int.random(in: 1...999))\",\"activity_timeout\":\(activityTimeout)}"
        )
    }

    /// Simulates the server or network closing the socket.
    func drop() {
        onClose?()
    }
}

final class ConnectionLifecycleTests: XCTestCase {
    private var transports: [MockTransport] = []
    private var states: [ConnectionState] = []
    private let lock = NSLock()

    override func setUp() {
        super.setUp()
        transports = []
        states = []
    }

    private func makeConnection(_ options: RealtimeOptions) -> Connection {
        let connection = Connection(
            options: options,
            onMessage: { _ in },
            onStateChange: { [weak self] _, curr in
                guard let self = self else { return }
                self.lock.lock(); self.states.append(curr); self.lock.unlock()
            },
            makeTransport: { [weak self] _ in
                let transport = MockTransport()
                self?.lock.lock(); self?.transports.append(transport); self?.lock.unlock()
                return transport
            }
        )
        connection.reconnectBaseDelay = 0.05
        return connection
    }

    private var transportCount: Int {
        lock.lock(); defer { lock.unlock() }
        return transports.count
    }

    private var lastTransport: MockTransport {
        lock.lock(); defer { lock.unlock() }
        return transports.last!
    }

    /// Polls until `condition` holds (callbacks hop onto the connection queue).
    private func waitUntil(
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertTrue(condition(), "condition not met within \(timeout)s", file: file, line: line)
    }

    private func connected(_ options: RealtimeOptions, serverTimeout: Double = 120) -> Connection {
        let connection = makeConnection(options)
        connection.connect()
        lastTransport.established(activityTimeout: serverTimeout)
        waitUntil { connection.state == .connected }
        return connection
    }

    func testReconnectsAfterDrop() {
        let connection = connected(RealtimeOptions(appKey: "k", cluster: "eu"))
        lastTransport.drop()

        waitUntil { self.transportCount == 2 }
        XCTAssertEqual(connection.state, .connecting)
        lastTransport.established()
        waitUntil { connection.state == .connected }
    }

    func testPingsAfterActivityTimeoutAndPongKeepsConnectionOpen() {
        let options = RealtimeOptions(appKey: "k", cluster: "eu", activityTimeout: 0.1, pongTimeout: 0.2)
        let connection = connected(options)
        let transport = lastTransport

        for _ in 0..<3 {
            let pings = transport.sentEvents.filter { $0 == "realtime:ping" }.count
            waitUntil { transport.sentEvents.filter { $0 == "realtime:ping" }.count == pings + 1 }
            transport.receive(event: "realtime:pong")
        }

        XCTAssertFalse(transport.closed)
        XCTAssertEqual(connection.state, .connected)
        XCTAssertEqual(transportCount, 1)
    }

    func testMissedPongReconnects() {
        let options = RealtimeOptions(appKey: "k", cluster: "eu", activityTimeout: 0.05, pongTimeout: 0.05)
        let connection = connected(options)
        let first = lastTransport

        waitUntil { first.closed }
        waitUntil { self.transportCount == 2 }
        withExtendedLifetime(connection) {}
    }

    func testActivityTimeoutOptionOverridesServerValue() {
        let options = RealtimeOptions(appKey: "k", cluster: "eu", activityTimeout: 0.1)
        let connection = connected(options, serverTimeout: 120)
        let transport = lastTransport
        waitUntil(timeout: 1) { transport.sentEvents.contains("realtime:ping") }
        withExtendedLifetime(connection) {}
    }

    func testServerActivityTimeoutUsedByDefault() {
        let connection = connected(RealtimeOptions(appKey: "k", cluster: "eu"), serverTimeout: 0.1)
        let transport = lastTransport
        waitUntil(timeout: 1) { transport.sentEvents.contains("realtime:ping") }
        withExtendedLifetime(connection) {}
    }

    func testDisconnectDoesNotReconnect() {
        let connection = connected(RealtimeOptions(appKey: "k", cluster: "eu"))
        let transport = lastTransport
        connection.disconnect()
        transport.drop() // late close from the old socket

        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(connection.state, .disconnected)
        XCTAssertTrue(transport.closed)
        XCTAssertEqual(transportCount, 1)
    }

    func testLateCloseFromReplacedSocketIsIgnored() {
        let connection = connected(RealtimeOptions(appKey: "k", cluster: "eu"))
        let old = lastTransport
        connection.disconnect()
        connection.connect()
        lastTransport.established()
        waitUntil { connection.state == .connected }

        old.drop()
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertEqual(connection.state, .connected)
        XCTAssertEqual(transportCount, 2)
    }

    func testEnableReconnectFalseGoesUnavailable() {
        let options = RealtimeOptions(appKey: "k", cluster: "eu", enableReconnect: false)
        let connection = connected(options)
        lastTransport.drop()

        waitUntil { connection.state == .unavailable }
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertEqual(transportCount, 1)
    }

    func testMaxReconnectAttempts() {
        let options = RealtimeOptions(appKey: "k", cluster: "eu", maxReconnectAttempts: 2)
        let connection = makeConnection(options)
        connection.connect()

        lastTransport.drop()
        waitUntil { self.transportCount == 2 }
        lastTransport.drop()
        waitUntil { self.transportCount == 3 }
        lastTransport.drop()
        waitUntil { connection.state == .unavailable }
    }

    func testKeepsReconnectingByDefault() {
        let connection = makeConnection(RealtimeOptions(appKey: "k", cluster: "eu"))
        connection.connect()
        // Past the 6 attempts the old default allowed (backoff 0.05s * 2^n).
        for i in 1...8 {
            lastTransport.drop()
            waitUntil(timeout: 10) { self.transportCount == i + 1 }
        }
        XCTAssertEqual(connection.state, .connecting)
    }

    func testResubscribeFromStateCallbackDoesNotDeadlock() {
        var connection: Connection!
        connection = Connection(
            options: RealtimeOptions(appKey: "k", cluster: "eu"),
            onMessage: { _ in },
            onStateChange: { _, curr in
                if curr == .connected {
                    connection.send(Message(event: "realtime:subscribe", channel: "c", data: "{}"))
                    _ = connection.state
                }
            },
            makeTransport: { [weak self] _ in
                let transport = MockTransport()
                self?.lock.lock(); self?.transports.append(transport); self?.lock.unlock()
                return transport
            }
        )
        connection.connect()
        lastTransport.established()
        let transport = lastTransport
        waitUntil { transport.sentEvents.contains("realtime:subscribe") }
    }
}
