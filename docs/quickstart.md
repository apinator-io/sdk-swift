# Quick Start

Get real-time events flowing in 5 steps.

## 1. Install

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/apinator-io/sdk-swift.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

## 2. Connect

```swift
import ApinatorSDK

let client = Apinator(appKey: "your-app-key", cluster: "eu")
client.connect()
```

## 3. Subscribe to a Channel

```swift
let channel = client.subscribe("notifications")
```

## 4. Bind to Events

```swift
channel.bind("new-message") { data in
    print("New message: \(data)")
}
```

## 5. Done!

Events published from your server (via the server SDK) will now arrive in real time.

---

## Next Steps

- **Private channels** — authenticate subscriptions via your backend. See [API Reference](api-reference.md).
- **Presence channels** — track who's online. See [API Reference](api-reference.md#presencechannel).
- **Client events** — send events directly between clients on private/presence channels.

## Triggering Events from the Server

Use the [Node.js server SDK](https://www.npmjs.com/package/@apinator/server) to publish events:

```typescript
import { RealtimeClient } from '@apinator/server';

const client = new RealtimeClient({
  appId: 'your-app-id',
  key: 'your-app-key',
  secret: 'your-app-secret',
  cluster: 'eu',
});

await client.trigger('notifications', 'new-message', {
  text: 'Hello from the server!',
});
```
