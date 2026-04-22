import Foundation

@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUserId: UUID?
    var currentEmail: String?
    var currentAvatarURL: String?
    var isLoading = false
    var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let accessTokenKey = "sb_access_token"
    private let refreshTokenKey = "sb_refresh_token"
    private let userIdKey = "sb_user_id"
    private let emailKey = "sb_email"
    private let avatarURLKey = "sb_avatar_url"

    init() {
        restoreSession()
    }

    private func restoreSession() {
        guard let accessToken = defaults.string(forKey: accessTokenKey),
              let refreshToken = defaults.string(forKey: refreshTokenKey),
              let userIdString = defaults.string(forKey: userIdKey),
              let userId = UUID(uuidString: userIdString) else {
            return
        }

        currentUserId = userId
        currentEmail = defaults.string(forKey: emailKey)
        currentAvatarURL = defaults.string(forKey: avatarURLKey)
        isAuthenticated = true

        Task {
            await SupabaseClient.shared.setSession(accessToken: accessToken, refreshToken: refreshToken)
            // Try refreshing to validate
            do {
                let response = try await SupabaseClient.shared.refreshSession()
                await MainActor.run {
                    self.saveSession(response)
                }
            } catch {
                await MainActor.run {
                    self.clearSession()
                }
            }
        }
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await SupabaseClient.shared.signUp(email: email, password: password)
            await MainActor.run {
                self.saveSession(response)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await SupabaseClient.shared.signIn(email: email, password: password)
            await MainActor.run {
                self.saveSession(response)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func signOut() async {
        await SupabaseClient.shared.signOut()
        await MainActor.run {
            clearSession()
        }
    }

    private func saveSession(_ response: SupabaseClient.AuthResponse) {
        defaults.set(response.accessToken, forKey: accessTokenKey)
        defaults.set(response.refreshToken, forKey: refreshTokenKey)
        defaults.set(response.user.id.uuidString, forKey: userIdKey)
        defaults.set(response.user.email, forKey: emailKey)
        defaults.set(response.user.userMetadata?.avatarURL, forKey: avatarURLKey)

        currentUserId = response.user.id
        currentEmail = response.user.email
        currentAvatarURL = response.user.userMetadata?.avatarURL
        isAuthenticated = true
    }

    func setAvatarURL(_ url: String?) {
        defaults.set(url, forKey: avatarURLKey)
        currentAvatarURL = url
    }

    private func clearSession() {
        let userId = currentUserId
        defaults.removeObject(forKey: accessTokenKey)
        defaults.removeObject(forKey: refreshTokenKey)
        defaults.removeObject(forKey: userIdKey)
        defaults.removeObject(forKey: emailKey)
        defaults.removeObject(forKey: avatarURLKey)

        currentUserId = nil
        currentEmail = nil
        currentAvatarURL = nil
        isAuthenticated = false

        if let userId {
            PhotoStorage.shared.deleteUser(userId: userId)
        }
    }
}
