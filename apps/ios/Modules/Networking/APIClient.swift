import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case unauthenticated
    case decodingError(Error)

    var userMessage: String {
        switch self {
        case .invalidURL: return "올바르지 않은 요청입니다."
        case .networkError: return "네트워크 연결이 지연되고 있습니다."
        case .invalidResponse: return "서버로부터 알 수 없는 응답을 받았습니다."
        case .httpError(let code): return "요청을 처리할 수 없습니다. (Code: \(code))"
        case .unauthenticated: return "로그인이 만료되었습니다. 다시 로그인해주세요."
        case .decodingError: return "데이터를 해석하는 중 오류가 발생했습니다."
        }
    }
}

final class APIClient: @unchecked Sendable {
    static let shared = APIClient()
    private let baseURL = "http://100.95.177.6:8000/v1"

    // Dynamic Auth Token
    private var authToken: String?
    private var isRefreshing = false
    private var pendingRefreshWaiters: [CheckedContinuation<String?, Never>] = []

    private init() {}

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        needsAuth: Bool = true,
        useIdempotency: Bool = false
    ) async throws -> T {

        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if needsAuth {
            guard let token = authToken else {
                throw APIError.unauthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if useIdempotency {
            let key = UUID().uuidString
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }

        if let body = body {
            request.httpBody = body
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // 401 → attempt token refresh (coalesced for concurrent requests)
        if httpResponse.statusCode == 401 && needsAuth {
            if let refreshed = await coalesceRefresh() {
                // Retry with new token
                var retryRequest = request
                retryRequest.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                if (200...299).contains(retryHttp.statusCode) {
                    do {
                        return try JSONDecoder().decode(T.self, from: retryData)
                    } catch {
                        #if DEBUG
                        let body = String(data: retryData, encoding: .utf8) ?? "<\(retryData.count) bytes>"
                        print("═══ DECODE ERROR (retry) ═══")
                        print("Type: \(T.self) | Body: \(body)")
                        print("Error: \(error)")
                        #endif
                        throw APIError.decodingError(error)
                    }
                }
                // Retry also failed — broadcast auth expired
                NotificationCenter.default.post(name: NSNotification.Name("AuthExpired"), object: nil)
                throw APIError.unauthenticated
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("AuthExpired"), object: nil)
                throw APIError.unauthenticated
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                NotificationCenter.default.post(name: NSNotification.Name("AuthExpired"), object: nil)
                throw APIError.unauthenticated
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            #if DEBUG
            let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
            print("═══ DECODE ERROR ═══")
            print("Type: \(T.self)")
            print("HTTP \(httpResponse.statusCode) \(url.absoluteString)")
            print("Body: \(body)")
            print("Error: \(error)")
            print("════════════════════")
            #endif
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Token Refresh (coalesced)

    /// Coalesces concurrent 401 refresh attempts: the first caller performs the refresh,
    /// subsequent callers wait for the same result.
    @MainActor
    private func coalesceRefresh() async -> String? {
        if isRefreshing {
            return await withCheckedContinuation { continuation in
                pendingRefreshWaiters.append(continuation)
            }
        }
        isRefreshing = true
        let result = await doRefresh()
        isRefreshing = false
        for waiter in pendingRefreshWaiters {
            waiter.resume(returning: result)
        }
        pendingRefreshWaiters.removeAll()
        return result
    }

    @MainActor
    private func doRefresh() async -> String? {
        guard let refreshToken = AuthManager.shared.currentRefreshToken else {
            return nil
        }

        let refreshRequest = TokenRefreshRequest(refresh_token: refreshToken)
        guard let body = try? JSONEncoder().encode(refreshRequest),
              let url = URL(string: baseURL + "/auth/token/refresh") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let tokenResponse = try? JSONDecoder().decode(AuthTokenResponse.self, from: data) else {
            return nil
        }

        // Save new tokens
        AuthManager.shared.saveTokens(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token
        )
        return tokenResponse.access_token
    }
}
