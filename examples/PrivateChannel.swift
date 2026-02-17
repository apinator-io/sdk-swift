import ApinatorSDK

// Create a client with auth endpoint for private channels
let client = Apinator(options: RealtimeOptions(
    appKey: "your-app-key",
    cluster: "eu",
    authEndpoint: "https://your-server.com/api/realtime/auth",
    authHeaders: ["Authorization": "Bearer your-token"]
))

client.connect()

// Subscribe to a private channel
let channel = client.subscribe("private-user-123")

channel.bind("realtime:subscription_succeeded") { _ in
    print("Subscribed to private channel")

    // Send a client event (only works on private/presence channels)
    do {
        try channel.trigger("client-typing", data: ["user": "alice"])
    } catch {
        print("Failed to trigger event: \(error)")
    }
}

channel.bind("realtime:subscription_error") { data in
    print("Subscription failed: \(data)")
}

// Listen for events
channel.bind("order-update") { data in
    print("Order update: \(data)")
}

// Listen for client events from other users
channel.bind("client-typing") { data in
    if let info = data as? [String: Any] {
        print("\(info["user"] ?? "someone") is typing...")
    }
}
