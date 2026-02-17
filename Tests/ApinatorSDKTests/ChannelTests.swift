import XCTest
@testable import ApinatorSDK

final class ChannelTests: XCTestCase {
    var channel: Channel!

    override func setUp() {
        super.setUp()
        channel = Channel(name: "test-channel")
    }

    override func tearDown() {
        channel = nil
        super.tearDown()
    }

    func testBind() {
        let expectation = XCTestExpectation(description: "Callback invoked")
        var receivedData: Any?

        channel.bind("test-event") { data in
            receivedData = data
            expectation.fulfill()
        }

        channel.emit("test-event", data: "test-data")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedData as? String, "test-data")
    }

    func testUnbind() {
        var callCount = 0

        channel.bind("test-event") { _ in
            callCount += 1
        }

        channel.emit("test-event", data: "data1")
        XCTAssertEqual(callCount, 1)

        channel.unbind("test-event")
        channel.emit("test-event", data: "data2")
        XCTAssertEqual(callCount, 1) // Should not increase
    }

    func testUnbindAll() {
        var event1Count = 0
        var event2Count = 0

        channel.bind("event1") { _ in event1Count += 1 }
        channel.bind("event2") { _ in event2Count += 1 }

        channel.emit("event1", data: "data")
        channel.emit("event2", data: "data")

        XCTAssertEqual(event1Count, 1)
        XCTAssertEqual(event2Count, 1)

        channel.unbindAll()

        channel.emit("event1", data: "data")
        channel.emit("event2", data: "data")

        XCTAssertEqual(event1Count, 1) // No change
        XCTAssertEqual(event2Count, 1) // No change
    }

    func testTriggerRequiresClientPrefix() {
        XCTAssertThrowsError(try channel.trigger("invalid-event", data: "data")) { error in
            XCTAssertTrue(error is RealtimeError)
        }

        // Should not throw with client- prefix
        let expectation = XCTestExpectation(description: "Trigger callback")
        channel.onTrigger = { event, data in
            XCTAssertEqual(event, "client-test")
            expectation.fulfill()
        }

        XCTAssertNoThrow(try channel.trigger("client-test", data: "data"))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleSubscribed() {
        let expectation = XCTestExpectation(description: "Subscription succeeded")

        channel.bind("realtime:subscription_succeeded") { _ in
            expectation.fulfill()
        }

        channel.handleSubscribed(nil)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(channel.subscribed)
    }

    func testHandleEvent() {
        let expectation = XCTestExpectation(description: "Event received")
        var receivedData: Any?

        channel.bind("custom-event") { data in
            receivedData = data
            expectation.fulfill()
        }

        channel.handleEvent("custom-event", data: "event-data")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedData as? String, "event-data")
    }
}
