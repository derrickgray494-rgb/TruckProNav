//
//  AppleSignInButton_Supabase.swift
//  TruckNavPro
//

import SwiftUI
import AuthenticationServices
import Supabase

struct AppleSignInButton_Supabase: View {
    var body: some View {
        SignInWithAppleButton(.signIn) { req in
            req.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                guard
                    let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = cred.identityToken,
                    let idToken = String(data: tokenData, encoding: .utf8)
                else {
                    print("❌ Missing Apple identity token")
                    return
                }
                Task { @MainActor in
                    do {
                        let session = try await SupabaseService.shared.client.auth.signInWithIdToken(
                            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken)
                        )
                        // Update AuthManager state
                        AuthManager.shared.currentUser = session.user
                        AuthManager.shared.isAuthenticated = true
                        print("✅ Apple sign-in via Supabase complete")
                    } catch {
                        print("❌ Supabase Apple sign-in failed: \(error)")
                    }
                }
            case .failure(let err):
                print("❌ Apple Sign-In error:", err)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6, y: 3)
    }
}
