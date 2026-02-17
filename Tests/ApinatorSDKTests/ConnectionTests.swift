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
        XCTAssertFalse(options.enableReconnect)
        XCTAssertEqual(options.maxReconnectAttempts, 3)
    }
}
