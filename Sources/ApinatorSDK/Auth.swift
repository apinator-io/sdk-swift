import Foundation

class AuthManager {
    static func fetchAuth(
        socketId: String,
        channelName: String,
        endpoint: String,
        headers: [String: String]?
    ) async throws -> AuthResponse {
        guard let url = URL(string: endpoint) else {
            throw RealtimeError.invalidConfiguration("Invalid auth endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Build request body
        let body: [String: String] = [
            "socket_id": socketId,
            "channel_name": channelName
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RealtimeError.authFailed("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RealtimeError.authFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        do {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            return authResponse
        } catch {
            throw RealtimeError.authFailed("Failed to decode auth response: \(error.localizedDescription)")
        }
    }
}
