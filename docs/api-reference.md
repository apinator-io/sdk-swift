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
| `activityTimeout` | `TimeInterval?` | No | `nil` (server value, 120) | Seconds without any server message before sending a ping |
| `pongTimeout` | `TimeInterval` | No | `30` | Seconds to wait for a reply to that ping before reconnecting |
| `enableReconnect` | `Bool` | No | `true` | Whether to auto-reconnect on disconnect |
| `maxReconnectAttempts` | `Int` | No | `.max` (unlimited) | Consecutive failed reconnects before going `unavailable` |

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


### Connection errors

`connect()` does nothing and the state becomes `.unavailable` if `appKey` or `cluster` is empty, `"undefined"` or `"null"`; the reason is printed. A missing cluster would otherwise retry an unreachable host forever.

When the server refuses a connection for a reason retrying cannot fix, it sends `realtime:error` with a code in **4000–4099** and a message saying what to change. The client prints the message, delivers the event to `bind("realtime:error")`, and moves to `.disconnected` without reconnecting.

| Code | Meaning |
|------|---------|
| 4001 | App key invalid: not set, an app ID instead of a key, a placeholder, or revoked. The message says which. |
| 4003 | App disabled |
| 4010 | Wrong cluster; the message names the right one |

Other close codes (e.g. 4200 server restart, network drops) reconnect automatically.

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
