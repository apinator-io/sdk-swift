import ApinatorSDK

// Create a client with auth endpoint for presence channels
let client = Apinator(options: RealtimeOptions(
    appKey: "your-app-key",
    cluster: "eu",
    authEndpoint: "https://your-server.com/api/realtime/auth",
    authHeaders: ["Authorization": "Bearer your-token"]
))

client.connect()

// Subscribe to a presence channel
let presence = client.subscribe("presence-chat-room") as! PresenceChannel

// Handle subscription success — members are now available
presence.bind("realtime:subscription_succeeded") { _ in
    print("Subscribed! Current members:")
    for member in presence.getMembers() {
        print("  - \(member.userId): \(member.userInfo)")
    }

    if let me = presence.me {
        print("I am: \(me.userId)")
    }

    print("Total members: \(presence.memberCount)")
}

// Handle new members joining
presence.bind("realtime:member_added") { data in
    if let member = data as? PresenceInfo {
        print("\(member.userId) joined the chat")
    }
}

// Handle members leaving
presence.bind("realtime:member_removed") { data in
    if let member = data as? PresenceInfo {
        print("\(member.userId) left the chat")
    }
}

// Listen for chat messages
presence.bind("message") { data in
    print("Chat message: \(data)")
}
