import XCTest
@testable import ApinatorSDK

final class PresenceChannelTests: XCTestCase {
    var channel: PresenceChannel!

    override func setUp() {
        super.setUp()
        channel = PresenceChannel(name: "presence-test")
    }

    override func tearDown() {
        channel = nil
        super.tearDown()
    }

    func testHandleSubscribed_populatesMembers() {
        let presenceData: [String: Any] = [
            "presence": [
                "members": [
                    ["user_id": "user1", "user_info": ["name": "Alice"]],
                    ["user_id": "user2", "user_info": ["name": "Bob"]]
                ],
                "me": "user1"
            ]
        ]

        channel.handleSubscribed(presenceData)

        XCTAssertEqual(channel.memberCount, 2)
        XCTAssertNotNil(channel.getMember("user1"))
        XCTAssertNotNil(channel.getMember("user2"))
        XCTAssertEqual(channel.me?.userId, "user1")
    }

    func testHandleMemberAdded() {
        let expectation = XCTestExpectation(description: "Member added event")
        var addedMember: PresenceInfo?

        channel.bind("realtime:member_added") { data in
            addedMember = data as? PresenceInfo
            expectation.fulfill()
        }

        let newMember = PresenceInfo(userId: "user3", userInfo: ["name": "Charlie"])
        channel.handleMemberAdded(newMember)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(addedMember?.userId, "user3")
        XCTAssertEqual(channel.memberCount, 1)
    }

    func testHandleMemberRemoved() {
        // Add a member first
        let member = PresenceInfo(userId: "user1", userInfo: ["name": "Alice"])
        channel.handleMemberAdded(member)
        XCTAssertEqual(channel.memberCount, 1)

        let expectation = XCTestExpectation(description: "Member removed event")
        var removedMember: PresenceInfo?

        channel.bind("realtime:member_removed") { data in
            removedMember = data as? PresenceInfo
            expectation.fulfill()
        }

        channel.handleMemberRemoved(member)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(removedMember?.userId, "user1")
        XCTAssertEqual(channel.memberCount, 0)
    }

    func testMe() {
        let presenceData: [String: Any] = [
            "presence": [
                "members": [
                    ["user_id": "user1", "user_info": ["name": "Alice"]],
                    ["user_id": "user2", "user_info": ["name": "Bob"]]
                ],
                "me": "user2"
            ]
        ]

        channel.handleSubscribed(presenceData)

        XCTAssertNotNil(channel.me)
        XCTAssertEqual(channel.me?.userId, "user2")
    }

    func testMemberCount() {
        XCTAssertEqual(channel.memberCount, 0)

        let presenceData: [String: Any] = [
            "presence": [
                "members": [
                    ["user_id": "user1", "user_info": ["name": "Alice"]],
                    ["user_id": "user2", "user_info": ["name": "Bob"]],
                    ["user_id": "user3", "user_info": ["name": "Charlie"]]
                ],
                "me": "user1"
            ]
        ]

        channel.handleSubscribed(presenceData)
        XCTAssertEqual(channel.memberCount, 3)
    }

    func testGetMembers() {
        let presenceData: [String: Any] = [
            "presence": [
                "members": [
                    ["user_id": "user1", "user_info": ["name": "Alice"]],
                    ["user_id": "user2", "user_info": ["name": "Bob"]]
                ],
                "me": "user1"
            ]
        ]

        channel.handleSubscribed(presenceData)

        let members = channel.getMembers()
        XCTAssertEqual(members.count, 2)

        let userIds = Set(members.map { $0.userId })
        XCTAssertTrue(userIds.contains("user1"))
        XCTAssertTrue(userIds.contains("user2"))
    }

    func testGetMember() {
        let presenceData: [String: Any] = [
            "presence": [
                "members": [
                    ["user_id": "user1", "user_info": ["name": "Alice"]]
                ],
                "me": "user1"
            ]
        ]

        channel.handleSubscribed(presenceData)

        let member = channel.getMember("user1")
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.userId, "user1")

        let nonExistent = channel.getMember("user999")
        XCTAssertNil(nonExistent)
    }
}
