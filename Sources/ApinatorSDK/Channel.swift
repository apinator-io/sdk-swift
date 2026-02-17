import Foundation

public class Channel {
    public let name: String
    private var bindings: [String: [EventCallbackWrapper]] = [:]
    private(set) var subscribed = false
    internal var onTrigger: ((String, Any) -> Void)?

    init(name: String) {
        self.name = name
    }

    @discardableResult
    public func bind(_ event: String, callback: @escaping EventCallback) -> Self {
        let wrapper = EventCallbackWrapper(callback: callback)

        if bindings[event] != nil {
            bindings[event]?.append(wrapper)
        } else {
            bindings[event] = [wrapper]
        }

        return self
    }

    @discardableResult
    public func unbind(_ event: String, callback: EventCallback? = nil) -> Self {
        if callback == nil {
            // Remove all callbacks for this event
            bindings.removeValue(forKey: event)
        } else {
            // Remove specific callback (not trivial with closures, so we remove all for now)
            // In a production SDK, you'd need to track callback identity
            bindings.removeValue(forKey: event)
        }

        return self
    }

    @discardableResult
    public func unbindAll() -> Self {
        bindings.removeAll()
        return self
    }

    public func trigger(_ event: String, data: Any) throws {
        guard event.hasPrefix("client-") else {
            throw RealtimeError.invalidMessage
        }

        emit("__trigger:\(event)", data: data)
    }

    func handleSubscribed(_ data: Any?) {
        subscribed = true
        emit("realtime:subscription_succeeded", data: data ?? [:])
    }

    func handleEvent(_ event: String, data: Any) {
        emit(event, data: data)
    }

    func handleError(_ data: Any) {
        emit("realtime:subscription_error", data: data)
    }

    func emit(_ event: String, data: Any) {
        // Special handling for trigger events
        if event.hasPrefix("__trigger:") {
            let actualEvent = String(event.dropFirst("__trigger:".count))
            onTrigger?(actualEvent, data)
            return
        }

        bindings[event]?.forEach { wrapper in
            wrapper.callback(data)
        }
    }
}

// Wrapper to make callbacks hashable/equatable if needed in future
class EventCallbackWrapper {
    let callback: EventCallback

    init(callback: @escaping EventCallback) {
        self.callback = callback
    }
}
