# API Reference

## Apinator

The main entry point for the SDK.

### Constructor

```swift
Apinator(options: RealtimeOptions)
Apinator(appKey: String, cluster: String)
Apinator(appKey: String, cluster: String, configure: (inout RealtimeOptions) -> Void)
```

#### RealtimeOptions

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `appKey` | `String` | Yes | — | Your application key |
| `cluster` | `String` | Yes | — | Region cluster ID (`eu`, `us`). Derives WebSocket URL as `wss://ws-{cluster}.apinator.io` |
| `authEndpoint` | `String?` | No | `nil` | URL for private/presence channel authentication |
| `authHeaders` | `[String: String]?` | No | `nil` | Custom headers sent with auth requests |
| `activityTimeout` | `TimeInterval` | No | `120` | Seconds before sending a ping |
| `enableReconnect` | `Bool` | No | `true` | Whether to auto-reconnect on disconnect |
| `maxReconnectAttempts` | `Int` | No | `6` | Maximum reconnection attempts before giving up |

### Methods

#### `connect() -> Self`

Opens the WebSocket connection. Returns the client instance for chaining.

#### `disconnect() -> Self`

Closes the WebSocket connection.

#### `subscribe(_ channelName: String) -> Channel`

Subscribes to a channel. Returns the `Channel` (or `PresenceChannel`) instance. If already subscribed, returns the existing instance.

- Channels prefixed with `private-` require authentication via `authEndpoint`.
- Channels prefixed with `presence-` require authentication and include member tracking.

#### `unsubscribe(_ channelName: String) -> Self`

Unsubscribes from a channel and removes all its bindings.

#### `channel(_ channelName: String) -> Channel?`

Returns the channel instance if subscribed, `nil` otherwise.

#### `bind(_ event: String, callback: @escaping EventCallback) -> Self`

Binds a callback to a global event (received on any channel).

#### `unbind(_ event: String, callback: EventCallback?) -> Self`

Unbinds a specific callback, or all callbacks for the event if no callback is provided.

#### `trigger(_ channelName: String, event: String, data: Any) -> Self`

Triggers a client event on a private or presence channel. Event name must start with `client-`.

### Properties

#### `socketId: String?`

The socket ID assigned by the server. Available after connection.

#### `state: ConnectionState`

Current connection state: `.initialized`, `.connecting`, `.connected`, `.unavailable`, `.disconnected`.

---

## Channel

Represents a subscription to a channel.

### Methods

#### `bind(_ event: String, callback: @escaping EventCallback) -> Self`

Binds a callback to an event on this channel.

#### `unbind(_ event: String, callback: EventCallback?) -> Self`

Unbinds a specific callback or all callbacks for the event.

#### `unbindAll() -> Self`

Removes all event bindings from this channel.

#### `trigger(_ event: String, data: Any) throws`

Triggers a client event. Only works on private/presence channels. Event name must start with `client-`. Throws `RealtimeError.invalidMessage` otherwise.

### Properties

#### `name: String`

The channel name (read-only).

#### `subscribed: Bool`

Whether the subscription has been confirmed by the server.

### Events

| Event | Data | Description |
|-------|------|-------------|
| `realtime:subscription_succeeded` | varies | Subscription confirmed |
| `realtime:subscription_error` | `Any` | Subscription failed |

---

## PresenceChannel

Extends `Channel` with member tracking. Created automatically when subscribing to `presence-` prefixed channels.

### Methods

#### `getMembers() -> [PresenceInfo]`

Returns all current members as an array.

#### `getMember(_ userId: String) -> PresenceInfo?`

Returns a specific member by user ID.

### Properties

#### `me: PresenceInfo?`

The current user's presence information. Set after `realtime:subscription_succeeded`.

#### `memberCount: Int`

Number of currently subscribed members.

### Events

| Event | Data | Description |
|-------|------|-------------|
| `realtime:member_added` | `PresenceInfo` | A new member joined |
| `realtime:member_removed` | `PresenceInfo` | A member left |

---

## Types

### `EventCallback`

```swift
typealias EventCallback = (Any) -> Void
```

### `ConnectionState`

```swift
enum ConnectionState: String {
    case initialized, connecting, connected, unavailable, disconnected
}
```

### `PresenceInfo`

```swift
struct PresenceInfo: Codable {
    let userId: String
    let userInfo: [String: AnyCodable]
}
```

### `RealtimeError`

```swift
enum RealtimeError: Error {
    case notConnected
    case authFailed(String)
    case connectionFailed(String)
    case invalidMessage
    case invalidConfiguration(String)
}
```

### `Message`

```swift
struct Message: Codable {
    let event: String
    let channel: String?
    let data: String
}
```
