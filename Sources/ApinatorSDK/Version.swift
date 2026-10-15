/// Release information sent to the server when connecting.
enum SDKInfo {
    /// This SDK's release version, sent as `?version=` on connect so the server can tell
    /// which release a client runs. release-please rewrites the line below on every
    /// release (`extra-files` in release-please-config.json); don't edit it by hand.
    static let version = "1.2.1" // x-release-please-version
}
