import Foundation
import Supabase
import AuthenticationServices
import SwiftUI
import SwiftData

@MainActor
@Observable
class AuthManager {
    private let supabase = SupabaseConfig.client
    
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    
    init() {
        checkAuthState()
        observeAuthChanges()
    }
    
    private func checkAuthState() {
        _Concurrency.Task {
            do {
                _ = try await supabase.auth.session
                self.isAuthenticated = true
            } catch {
                self.isAuthenticated = false
            }
        }
    }
    
    private func observeAuthChanges() {
        _Concurrency.Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    self.isAuthenticated = session != nil
                case .signedIn:
                    self.isAuthenticated = true
                case .signedOut:
                    self.isAuthenticated = false
                case .tokenRefreshed, .userUpdated, .mfaChallengeVerified,
                     .userDeleted, .passwordRecovery:
                    break
                }
            }
        }
    }
    
    /// Sign in with Apple using the credential from the native button
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let authorization = try result.get()
            
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idToken = credential.identityToken,
                  let idTokenString = String(data: idToken, encoding: .utf8) else {
                throw AuthError.invalidToken
            }
            
            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idTokenString
                )
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "com.jensen.docket://auth-callback")
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func signInWithEmail(_ email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "com.jensen.docket://auth-callback")
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func signOut(modelContext: ModelContext) async {
        do {
            // Clear all local data before signing out
            clearLocalData(modelContext: modelContext)
            
            try await supabase.auth.signOut()
            self.isAuthenticated = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    /// Wipes all local SwiftData records and UserDefaults to prevent data leaking between accounts
    private func clearLocalData(modelContext: ModelContext) {
        // Delete all SwiftData records
        do {
            try modelContext.delete(model: Task.self)
            try modelContext.delete(model: GroceryStore.self)
            try modelContext.delete(model: IngredientLibrary.self)
            try modelContext.save()
        } catch {
            print("Error clearing local data: \(error)")
        }
        
        // Clear UserDefaults for app-specific keys
        UserDefaults.standard.removeObject(forKey: "savedStores")
        UserDefaults.standard.removeObject(forKey: "savedCategories")
        UserDefaults.standard.removeObject(forKey: "notifications.remindersEnabled")
        UserDefaults.standard.removeObject(forKey: "notifications.shareAlertsEnabled")
        UserDefaults.standard.removeObject(forKey: "notifications.defaultReminderMinutes")
    }
    
    func handleAuthCallback(url: URL) {
        // Use handle() method for SwiftUI - this processes the auth callback URL
        // The auth state changes will be picked up by observeAuthChanges()
        supabase.auth.handle(url)
    }
    
    func currentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            return nil
        }
    }
}

enum AuthError: LocalizedError {
    case invalidToken
    case invalidCredential
    
    var errorDescription: String? {
        switch self {
        case .invalidToken: return "Invalid authentication token"
        case .invalidCredential: return "Invalid authentication credential"
        }
    }
}
