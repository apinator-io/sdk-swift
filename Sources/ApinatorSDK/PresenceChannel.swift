import Foundation

public class PresenceChannel: Channel {
    private var members: [String: PresenceInfo] = [:]
    private var myID: String?

    public var me: PresenceInfo? {
        guard let myID = myID else { return nil }
        return members[myID]
    }

    public var memberCount: Int {
        return members.count
    }

    public func getMembers() -> [PresenceInfo] {
        return Array(members.values)
    }

    public func getMember(_ userId: String) -> PresenceInfo? {
        return members[userId]
    }

    override func handleSubscribed(_ data: Any?) {
        // Parse presence data
        if let dict = data as? [String: Any] {
            if let presenceData = dict["presence"] as? [String: Any] {
                // Extract members array
                if let membersList = presenceData["members"] as? [[String: Any]] {
                    for memberData in membersList {
                        if let userId = memberData["user_id"] as? String,
                           let userInfo = memberData["user_info"] as? [String: Any] {
                            let presenceInfo = PresenceInfo(userId: userId, userInfo: userInfo)
                            members[userId] = presenceInfo
                        }
                    }
                }

                // Extract myID
                if let meId = presenceData["me"] as? String {
                    myID = meId
                }
            }
        }

        super.handleSubscribed(data)
    }

    func handleMemberAdded(_ info: PresenceInfo) {
        members[info.userId] = info
        emit("realtime:member_added", data: info)
    }

    func handleMemberRemoved(_ info: PresenceInfo) {
        members.removeValue(forKey: info.userId)
        emit("realtime:member_removed", data: info)
    }

    override func handleEvent(_ event: String, data: Any) {
        // Handle presence-specific events
        switch event {
        case "realtime:member_added":
            if let dict = data as? [String: Any],
               let userId = dict["user_id"] as? String,
               let userInfo = dict["user_info"] as? [String: Any] {
                let info = PresenceInfo(userId: userId, userInfo: userInfo)
                handleMemberAdded(info)
                return
            }

        case "realtime:member_removed":
            if let dict = data as? [String: Any],
               let userId = dict["user_id"] as? String {
                if let info = members[userId] {
                    handleMemberRemoved(info)
                    return
                }
            }

        default:
            break
        }

        super.handleEvent(event, data: data)
    }
}
