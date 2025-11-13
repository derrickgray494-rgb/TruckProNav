//
//  SignUpView_Tron.swift
//  TruckNavPro
//

import SwiftUI
import AuthenticationServices

struct SignUpView_Tron: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field { case email, password, confirm }

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

            VStack(alignment: .center, spacing: 25) {
                Spacer().frame(height: 40)

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
                .padding(.bottom, 30)

                // Input Fields
                VStack(spacing: 16) {
                    customField(icon: "envelope.fill", placeholder: "Email", text: $email, field: .email, isSecure: false)
                    customField(icon: "lock.fill", placeholder: "Password", text: $password, field: .password, isSecure: true)
                    customField(icon: "lock.fill", placeholder: "Confirm Password", text: $confirmPassword, field: .confirm, isSecure: true)
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

                // Sign Up Button
                Button(action: signUp) {
                    ZStack {
                        Text("Create Account")
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
                .padding(.top, 10)
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

                // Sign In Link
                HStack(spacing: 6) {
                    Text("Already have an account?")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))

                    Button("Sign In") {
                        NotificationCenter.default.post(name: .showSignIn, object: nil)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(neonBlue)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func customField(icon: String, placeholder: String, text: Binding<String>, field: Field, isSecure: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(neonBlue.opacity(0.95))
                .frame(width: 22)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: field)
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == field ? neonBlue : .white.opacity(0.25), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
        )
        .shadow(color: (focusedField == field ? neonBlue : .clear).opacity(0.6), radius: 8)
    }

    // MARK: - Actions

    private func signUp() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await AuthManager.shared.signUp(email: email, password: password)
                await MainActor.run {
                    NotificationCenter.default.post(name: .userDidSignUp, object: nil)
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
