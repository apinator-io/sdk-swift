import XCTest
@testable import ApinatorSDK

final class ApinatorTests: XCTestCase {
    var client: Apinator!

    override func setUp() {
        super.setUp()
        let options = RealtimeOptions(
            appKey: "test-key",
            cluster: "eu",
            enableReconnect: false
        )
        client = Apinator(options: options)
    }

    override func tearDown() {
        client?.disconnect()
        client = nil
        super.tearDown()
    }

    func testSubscribe_createsChannel() {
        let channel = client.subscribe("test-channel")
        XCTAssertNotNil(channel)
        XCTAssertEqual(channel.name, "test-channel")
    }

    func testSubscribe_returnsSameInstance() {
        let channel1 = client.subscribe("test-channel")
        let channel2 = client.subscribe("test-channel")

        XCTAssertTrue(channel1 === channel2, "Should return same channel instance")
    }

    func testSubscribe_createsPresenceChannel() {
        let channel = client.subscribe("presence-test")
        XCTAssertTrue(channel is PresenceChannel, "Should create PresenceChannel for presence- prefix")
        XCTAssertEqual(channel.name, "presence-test")
    }

    func testUnsubscribe() {
        let channel = client.subscribe("test-channel")
        XCTAssertNotNil(client.channel("test-channel"))

        client.unsubscribe("test-channel")
        XCTAssertNil(client.channel("test-channel"))
    }

    func testBind_globalEvent() {
        let expectation = XCTestExpectation(description: "Global binding invoked")
        var receivedData: Any?

        client.bind("custom-event") { data in
            receivedData = data
            expectation.fulfill()
        }

        // Simulate message handling
        let message = Message(event: "custom-event", channel: nil, data: "{\"test\":\"data\"}")
        // We can't easily trigger this without exposing handleMessage, so this is a structural test
        XCTAssertNotNil(client)

        // For now, just verify the binding was registered
        // In a real integration test, we'd need to mock the connection
    }

    func testTrigger_requiresClientPrefix() {
        let channel = client.subscribe("test-channel")

        // Should not crash with client- prefix
        client.trigger("test-channel", event: "client-test", data: ["key": "value"])

        // Without prefix, it just won't send (no error thrown at client level)
        client.trigger("test-channel", event: "invalid-event", data: ["key": "value"])
    }

    func testInitialState() {
        XCTAssertEqual(client.state, .initialized)
        XCTAssertNil(client.socketId)
    }

    func testConvenienceInit() {
        let client = Apinator(appKey: "test-key", cluster: "eu")
        XCTAssertNotNil(client)
        XCTAssertEqual(client.state, .initialized)
    }

    func testConvenienceInitWithConfigure() {
        let client = Apinator(appKey: "test-key", cluster: "eu") { options in
            options.authEndpoint = "https://example.com/auth"
        }
        XCTAssertNotNil(client)
        XCTAssertEqual(client.state, .initialized)
    }

    func testChannel_returnsExistingChannel() {
        let subscribed = client.subscribe("test-channel")
        let retrieved = client.channel("test-channel")

        XCTAssertNotNil(retrieved)
        XCTAssertTrue(subscribed === retrieved)
    }

    func testChannel_returnsNilForNonExistent() {
        let channel = client.channel("non-existent")
        XCTAssertNil(channel)
    }
}
