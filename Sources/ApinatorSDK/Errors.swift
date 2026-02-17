import Foundation

public enum RealtimeError: Error, LocalizedError {
    case notConnected
    case authFailed(String)
    case connectionFailed(String)
    case invalidMessage
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to WebSocket server"
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .invalidMessage:
            return "Invalid message format"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}
