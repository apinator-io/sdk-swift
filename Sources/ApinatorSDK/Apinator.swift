import Foundation

public class Apinator {
    private var connection: Connection!
    private var channels: [String: Channel] = [:]
    private let options: RealtimeOptions
    private var globalBindings: [String: [EventCallbackWrapper]] = [:]

    public init(options: RealtimeOptions) {
        self.options = options

        // Create connection with proper callbacks
        self.connection = Connection(
            options: options,
            onMessage: { [weak self] message in
                self?.handleMessage(message)
            },
            onStateChange: { [weak self] prev, curr in
                self?.handleStateChange(prev, curr)
            }
        )
    }

    @discardableResult
    public func connect() -> Self {
        connection.connect()
        return self
    }

    @discardableResult
    public func disconnect() -> Self {
        connection.disconnect()
        return self
    }

    public var socketId: String? {
        return connection.socketId
    }

    public var state: ConnectionState {
        return connection.state
    }

    public func subscribe(_ channelName: String) -> Channel {
        // Return existing channel if already subscribed
        if let existing = channels[channelName] {
            return existing
        }

        // Create appropriate channel type
        let channel: Channel
        if channelName.hasPrefix("presence-") {
            channel = PresenceChannel(name: channelName)
        } else {
            channel = Channel(name: channelName)
        }

        // Set up trigger callback
        channel.onTrigger = { [weak self] event, data in
            guard let self = self else { return }
            self.sendTrigger(channelName: channelName, event: event, data: data)
        }

        channels[channelName] = channel

        // Send subscribe if connected
        if connection.state == .connected {
            sendSubscribe(channel)
        }

        return channel
    }

    @discardableResult
    public func unsubscribe(_ channelName: String) -> Self {
        guard let channel = channels[channelName] else {
            return self
        }

        channels.removeValue(forKey: channelName)

        // Send unsubscribe message
        if connection.state == .connected {
            let message = Message(
                event: "realtime:unsubscribe",
                channel: channelName,
                data: "{}"
            )
            connection.send(message)
        }

        return self
    }

    public func channel(_ channelName: String) -> Channel? {
        return channels[channelName]
    }

    @discardableResult
    public func bind(_ event: String, callback: @escaping EventCallback) -> Self {
        let wrapper = EventCallbackWrapper(callback: callback)

        if globalBindings[event] != nil {
            globalBindings[event]?.append(wrapper)
        } else {
            globalBindings[event] = [wrapper]
        }

        return self
    }

    @discardableResult
    public func unbind(_ event: String, callback: EventCallback? = nil) -> Self {
        if callback == nil {
            globalBindings.removeValue(forKey: event)
        } else {
            // Remove specific callback
            globalBindings.removeValue(forKey: event)
        }

        return self
    }

    @discardableResult
    public func trigger(_ channelName: String, event: String, data: Any) -> Self {
        guard event.hasPrefix("client-") else {
            return self
        }

        sendTrigger(channelName: channelName, event: event, data: data)
        return self
    }

    private func sendTrigger(channelName: String, event: String, data: Any) {
        guard connection.state == .connected else {
            return
        }

        // Serialize data to JSON string
        let dataString: String
        if let string = data as? String {
            dataString = string
        } else if let dict = data as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let string = String(data: jsonData, encoding: .utf8) {
            dataString = string
        } else if let array = data as? [Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: array),
                  let string = String(data: jsonData, encoding: .utf8) {
            dataString = string
        } else {
            dataString = "{}"
        }

        let message = Message(
            event: event,
            channel: channelName,
            data: dataString
        )

        connection.send(message)
    }

    private func handleMessage(_ msg: Message) {
        // Route to specific channel if present
        if let channelName = msg.channel, let channel = channels[channelName] {
            // Parse data
            let data = parseMessageData(msg.data)

            switch msg.event {
            case "realtime:subscription_succeeded":
                channel.handleSubscribed(data)

            case "realtime:subscription_error":
                channel.handleError(data)

            default:
                channel.handleEvent(msg.event, data: data)
            }
        }

        // Fire global bindings
        let data = parseMessageData(msg.data)
        globalBindings[msg.event]?.forEach { wrapper in
            wrapper.callback(data)
        }
    }

    private func handleStateChange(_ prev: ConnectionState, _ curr: ConnectionState) {
        if curr == .connected {
            // Resubscribe all channels
            for (_, channel) in channels {
                sendSubscribe(channel)
            }
        }

        // Fire state_change global binding
        let stateChangeData: [String: String] = [
            "previous": prev.rawValue,
            "current": curr.rawValue
        ]

        globalBindings["state_change"]?.forEach { wrapper in
            wrapper.callback(stateChangeData)
        }
    }

    private func sendSubscribe(_ channel: Channel) {
        let channelName = channel.name

        // Public channel - no auth needed
        if !channelName.hasPrefix("private-") && !channelName.hasPrefix("presence-") {
            let message = Message(
                event: "realtime:subscribe",
                channel: channelName,
                data: "{}"
            )
            connection.send(message)
            return
        }

        // Private/presence channel - need auth
        guard let socketId = connection.socketId,
              let authEndpoint = options.authEndpoint else {
            channel.handleError(["message": "Auth endpoint not configured"])
            return
        }

        // Fetch auth token asynchronously
        Task {
            do {
                let authResponse = try await AuthManager.fetchAuth(
                    socketId: socketId,
                    channelName: channelName,
                    endpoint: authEndpoint,
                    headers: options.authHeaders
                )

                // Build subscribe message with auth
                var dataDict: [String: String] = ["auth": authResponse.auth]
                if let channelData = authResponse.channelData {
                    dataDict["channel_data"] = channelData
                }

                let jsonData = try JSONSerialization.data(withJSONObject: dataDict)
                let dataString = String(data: jsonData, encoding: .utf8) ?? "{}"

                let message = Message(
                    event: "realtime:subscribe",
                    channel: channelName,
                    data: dataString
                )

                connection.send(message)

            } catch {
                channel.handleError(["message": error.localizedDescription])
            }
        }
    }

    private func parseMessageData(_ dataString: String) -> Any {
        guard let data = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return dataString
        }
        return json
    }
}

extension Apinator {
    public convenience init(appKey: String, cluster: String) {
        let options = RealtimeOptions(appKey: appKey, cluster: cluster)
        self.init(options: options)
    }

    public convenience init(appKey: String, cluster: String, configure: (inout RealtimeOptions) -> Void) {
        var options = RealtimeOptions(appKey: appKey, cluster: cluster)
        configure(&options)
        self.init(options: options)
    }
}
