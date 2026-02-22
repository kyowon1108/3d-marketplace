import Foundation
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AuthUserResponse?

    // Keychain keys
    private let tokenService = "com.codyssey.3dmarketplace"
    private let accessTokenAccount = "accessToken"
    private let refreshTokenAccount = "refreshToken"

    private init() {
        checkToken()
    }

    var currentToken: String? {
        guard let data = KeychainHelper.shared.read(service: tokenService, account: accessTokenAccount),
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    var currentRefreshToken: String? {
        guard let data = KeychainHelper.shared.read(service: tokenService, account: refreshTokenAccount),
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    func saveTokens(accessToken: String, refreshToken: String? = nil) {
        if let data = accessToken.data(using: .utf8) {
            KeychainHelper.shared.save(data, service: tokenService, account: accessTokenAccount)
            isAuthenticated = true
            APIClient.shared.setAuthToken(accessToken)
        }
        if let refreshToken = refreshToken, let data = refreshToken.data(using: .utf8) {
            KeychainHelper.shared.save(data, service: tokenService, account: refreshTokenAccount)
        }
        Task {
            await fetchCurrentUser()
        }
    }

    /// Legacy single-token save for backward compatibility.
    func saveToken(_ token: String) {
        saveTokens(accessToken: token)
    }

    func logout() {
        // Try to notify server
        if let refreshToken = currentRefreshToken {
            Task {
                let request = LogoutRequest(refresh_token: refreshToken)
                if let body = try? JSONEncoder().encode(request) {
                    let _: EmptyResponse? = try? await APIClient.shared.request(
                        endpoint: "/auth/logout",
                        method: "POST",
                        body: body
                    )
                }
            }
        }

        KeychainHelper.shared.delete(service: tokenService, account: accessTokenAccount)
        KeychainHelper.shared.delete(service: tokenService, account: refreshTokenAccount)
        isAuthenticated = false
        currentUser = nil
        APIClient.shared.setAuthToken(nil)
    }

    private func checkToken() {
        if let token = currentToken {
            isAuthenticated = true
            APIClient.shared.setAuthToken(token)
            Task {
                await fetchCurrentUser()
            }
        }
    }

    func fetchCurrentUser() async {
        do {
            let user: AuthUserResponse = try await APIClient.shared.request(endpoint: "/auth/me")
            self.currentUser = user
        } catch {
            print("Failed to fetch current user: \(error)")
            if case APIError.unauthenticated = error {
                logout()
            }
        }
    }
}
