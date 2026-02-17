# ApinatorSDK

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/apinator-io/sdk-swift/test.yml?label=CI)](https://github.com/apinator-io/sdk-swift/actions/workflows/test.yml)

Swift client SDK for [Apinator](https://apinator.io) — real-time WebSocket messaging for iOS and macOS applications.

## Features

- Public, private, and presence channels
- Automatic reconnection with exponential backoff
- Client events on private/presence channels
- Presence member tracking
- Zero dependencies — uses only Foundation and URLSessionWebSocketTask
- iOS 13+ / macOS 10.15+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/apinator-io/sdk-swift.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import ApinatorSDK

let client = Apinator(appKey: "your-app-key", cluster: "eu")
client.connect()

let channel = client.subscribe("my-channel")

channel.bind("my-event") { data in
    print("Received: \(data)")
}
```

## Channel Types

### Public Channels

No authentication required. Any client can subscribe.

```swift
let channel = client.subscribe("news")
channel.bind("update") { data in /* ... */ }
```

### Private Channels

Require server-side authentication. Prefix with `private-`.

```swift
let client = Apinator(options: RealtimeOptions(
    appKey: "your-app-key",
    cluster: "eu",
    authEndpoint: "https://your-server.com/api/realtime/auth"
))

let channel = client.subscribe("private-orders")
channel.bind("new-order") { data in /* ... */ }
```

### Presence Channels

Like private channels, but also track who is subscribed. Prefix with `presence-`.

```swift
let presence = client.subscribe("presence-chat") as! PresenceChannel

presence.bind("realtime:subscription_succeeded") { _ in
    print("Members: \(presence.getMembers())")
    print("Me: \(String(describing: presence.me))")
}

presence.bind("realtime:member_added") { data in
    print("Joined: \(data)")
}

presence.bind("realtime:member_removed") { data in
    print("Left: \(data)")
}
```

## Client Events

Trigger events directly from the client on private or presence channels:

```swift
let privateChannel = client.subscribe("private-chat")
try privateChannel.trigger("client-typing", data: ["user": "alice"])
```

## Connection States

Monitor the connection lifecycle:

```swift
client.bind("state_change") { data in
    if let stateChange = data as? [String: String] {
        print("\(stateChange["previous"]!) -> \(stateChange["current"]!)")
    }
}
```

States: `initialized` -> `connecting` -> `connected` -> `disconnected` / `unavailable`

## API Reference

See [docs/api-reference.md](docs/api-reference.md) for the full API.

## Platform Support

- iOS 13+
- macOS 10.15+

## Links

- [Quick Start Tutorial](docs/quickstart.md)
- [API Reference](docs/api-reference.md)
- [Architecture Guide](docs/architecture.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## License

MIT — see [LICENSE](LICENSE).
