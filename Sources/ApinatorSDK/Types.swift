import Foundation

public struct RealtimeOptions {
    public let appKey: String
    public let cluster: String
    public var authEndpoint: String?
    public var authHeaders: [String: String]?
    public var activityTimeout: TimeInterval
    public var enableReconnect: Bool
    public var maxReconnectAttempts: Int

    public init(
        appKey: String,
        cluster: String,
        authEndpoint: String? = nil,
        authHeaders: [String: String]? = nil,
        activityTimeout: TimeInterval = 120,
        enableReconnect: Bool = true,
        maxReconnectAttempts: Int = 6
    ) {
        self.appKey = appKey
        self.cluster = cluster
        self.authEndpoint = authEndpoint
        self.authHeaders = authHeaders
        self.activityTimeout = activityTimeout
        self.enableReconnect = enableReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
    }
}

public struct Message: Codable {
    public let event: String
    public let channel: String?
    public let data: String

    public init(event: String, channel: String? = nil, data: String) {
        self.event = event
        self.channel = channel
        self.data = data
    }
}

public struct PresenceInfo: Codable {
    public let userId: String
    public let userInfo: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userInfo = "user_info"
    }

    public init(userId: String, userInfo: [String: Any]) {
        self.userId = userId
        self.userInfo = userInfo.mapValues { AnyCodable($0) }
    }
}

// Helper to encode/decode Any values in JSON
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            let context = EncodingError.Context(codingPath: [], debugDescription: "Unsupported type")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

public struct AuthResponse: Codable {
    public let auth: String
    public let channelData: String?

    enum CodingKeys: String, CodingKey {
        case auth
        case channelData = "channel_data"
    }
}

public enum ConnectionState: String {
    case initialized
    case connecting
    case connected
    case unavailable
    case disconnected
}

public typealias EventCallback = (Any) -> Void
public typealias StateChangeCallback = (ConnectionState, ConnectionState) -> Void
