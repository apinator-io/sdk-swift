import ApinatorSDK

// Create a client with your app key and cluster
let client = Apinator(appKey: "your-app-key", cluster: "eu")

// Monitor connection state changes
client.bind("state_change") { data in
    if let stateChange = data as? [String: String] {
        print("Connection: \(stateChange["previous"]!) -> \(stateChange["current"]!)")
    }
}

// Connect to the server
client.connect()

// Subscribe to a public channel
let channel = client.subscribe("notifications")

// Bind to events
channel.bind("new-message") { data in
    print("Received message: \(data)")
}

channel.bind("realtime:subscription_succeeded") { _ in
    print("Subscribed to notifications channel")
}

// Later: unsubscribe and disconnect
// client.unsubscribe("notifications")
// client.disconnect()
