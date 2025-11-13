//
//  SignInView_Tron.swift
//  TruckNavPro
//

import SwiftUI
import AuthenticationServices

struct SignInView_Tron: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: NeonField.Field?

    // Tron colors
    private let neonBlue = Color(red: 0.2, green: 0.7, blue: 1.0)
    private let darkBg = Color(red: 0.05, green: 0.05, blue: 0.1)

    var body: some View {
        ZStack {
            // Background
            Image("truck_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(darkBg.opacity(0.85))

            VStack(alignment: .center, spacing: 30) {
                Spacer()

                // Neon Logo & Subtitle
                VStack(alignment: .center, spacing: 16) {
                    Text("TRUCKNAV PRO")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [neonBlue, Color.cyan, neonBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: neonBlue, radius: 20, x: 0, y: 0)
                        .shadow(color: neonBlue.opacity(0.5), radius: 40, x: 0, y: 0)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("Join the future of truck navigation.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)

                // Input Fields
                VStack(spacing: 18) {
                    NeonField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        isSecure: false,
                        focusedField: _focusedField,
                        field: .email,
                        neon: neonBlue
                    )

                    NeonField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true,
                        focusedField: _focusedField,
                        field: .password,
                        neon: neonBlue
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .disabled(isLoading)

                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 30)
                }

                // Sign In Button
                Button(action: signIn) {
                    ZStack {
                        Text("Sign In")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                    }
                }
                .background(
                    LinearGradient(
                        colors: [neonBlue, Color.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: neonBlue.opacity(0.8), radius: 12, y: 4)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .disabled(isLoading)

                // Or divider
                Text("or")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)

                // Apple Sign In
                AppleSignInButton_Supabase()
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .disabled(isLoading)

                // Forgot Password Link
                Button("Forgot Password?") {
                    NotificationCenter.default.post(name: .showPasswordReset, object: nil)
                }
                .font(.system(size: 14))
                .foregroundColor(neonBlue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                // Sign Up Link
                HStack(spacing: 6) {
                    Text("Don't have an account?")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))

                    Button("Sign Up") {
                        NotificationCenter.default.post(name: .showSignUp, object: nil)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(neonBlue)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await AuthManager.shared.signIn(email: email, password: password)
                await MainActor.run {
                    NotificationCenter.default.post(name: .userDidSignIn, object: nil)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
