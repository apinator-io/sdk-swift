# Changelog

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
