# Changelog

## [1.2.1](https://github.com/apinator-io/sdk-swift/compare/v1.2.0...v1.2.1) (2026-10-15)


### Bug Fixes

* report the real SDK version when connecting ([#6](https://github.com/apinator-io/sdk-swift/issues/6)) ([d5d9a21](https://github.com/apinator-io/sdk-swift/commit/d5d9a21f6818a3210eebdcc0cfab60421c54fe11))

## [1.2.0](https://github.com/apinator-io/sdk-swift/compare/v1.1.0...v1.2.0) (2026-10-14)


### ⚠ Behaviour change

* `connect()` now refuses an `appKey` or `cluster` that is empty, `"undefined"` or `"null"`. It prints the reason and moves to `.unavailable` instead of retrying an unreachable host forever [d90c508](https://github.com/apinator-io/sdk-swift/commit/d90c5085a46e5b83e7815085e13598d32a7029ba)


### Bug Fixes

* **errors:** a connection refused for a reason retrying cannot fix (any `realtime:error` or close code 4000–4099: invalid app key, app disabled, wrong cluster) now stops the client instead of reconnecting forever. Previously only 4000–4004 did [d90c508](https://github.com/apinator-io/sdk-swift/commit/d90c5085a46e5b83e7815085e13598d32a7029ba)
* **errors:** fatal errors now reach `bind("realtime:error")`; they were dropped before the app could see them [d90c508](https://github.com/apinator-io/sdk-swift/commit/d90c5085a46e5b83e7815085e13598d32a7029ba)
* **transport:** the server's close code is now passed to the connection, so a fatal close without an error message also stops reconnecting, while 4200 (server restart) still reconnects [d90c508](https://github.com/apinator-io/sdk-swift/commit/d90c5085a46e5b83e7815085e13598d32a7029ba)


### Features

* the server's explanation is printed as `[apinator] <message> (code N)`. With the current server it names the likely mistake: an app ID used as the key, a placeholder from an example, a revoked key, or the cluster to use [d90c508](https://github.com/apinator-io/sdk-swift/commit/d90c5085a46e5b83e7815085e13598d32a7029ba)

## [1.1.0](https://github.com/apinator-io/sdk-swift/compare/v1.0.0...v1.1.0) (2026-10-13)


### ⚠ Changes to be aware of

* `RealtimeOptions.activityTimeout` is now `TimeInterval?`. `nil` (the default) uses the server's value. Passing a number still compiles; code that reads the property needs to unwrap it.
* Reconnection is now unlimited by default; 1.0.0 gave up after 6 attempts. Set `maxReconnectAttempts` to restore a limit.
* While waiting to reconnect the state is `.connecting` (it was `.disconnected`). `.disconnected` now always means `disconnect()` was called.
* `onMessage` / `onStateChange` (and `Apinator` bindings) run on the connection's serial queue. They were already off the main thread.


### Bug Fixes

* **reconnect:** the client never reconnected after a dropped connection. Its timers were created with `Timer.scheduledTimer` on URLSession's background queue, which has no run loop, so they never fired. All timers are now GCD timers on a private serial queue [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)
* **keep-alive:** pings never ran for the same reason, and a pong never re-armed the activity timer. Every server message now re-arms it, and a missed pong drops the socket and reconnects immediately [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)
* **disconnect:** `disconnect()` could trigger a reconnect, and a single close was handled twice (receive failure and delegate) [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)
* a late close from a replaced socket no longer tears down the current connection [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)
* each connection attempt leaked a `URLSession` (never invalidated, and it retains its delegate) [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)
* `activityTimeout` was ignored whenever the server sent its own value [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)


### Features

* `pongTimeout` option (default 30s) [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)
* reconnect delays are jittered (50–100% of the backoff) so clients dropped together don't reconnect in lockstep [64a92e8](https://github.com/apinator-io/sdk-swift/commit/64a92e8e84db45a6840afcfc4ce9d6c660252d49)

## 1.0.0 (2026-02-17)


### Bug Fixes

* tests pipeline ([9e612ed](https://github.com/apinator-io/sdk-swift/commit/9e612ed100a45b89c2c51c1befa34d7c05b9e8d7))

## [1.0.0](https://github.com/apinator-io/sdk-swift/releases/tag/v1.0.0) (2026-02-17)

### Features

* `Apinator` client with connect/disconnect lifecycle
* Public channel subscriptions
* Private channel authentication via `authEndpoint`
* Presence channels with member tracking
* Client events on private/presence channels (`client-` prefix)
* Automatic reconnection with exponential backoff (max 30s)
* Activity timeout with ping/pong keep-alive
* Global event bindings across all channels
* Connection state machine (`initialized` -> `connecting` -> `connected` -> `disconnected` / `unavailable`)
* Cluster-based URL resolution (`wss://ws-{cluster}.apinator.io`)
* iOS 13+ / macOS 10.15+ support via Swift Package Manager
