//
//  PasswordResetView_Tron.swift
//  TruckNavPro
//

import SwiftUI

struct PasswordResetView_Tron: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @FocusState private var emailFocused: Bool

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

            VStack(spacing: 30) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(neonBlue)
                        .shadow(color: neonBlue.opacity(0.8), radius: 20)

                    Text("Reset Password")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: neonBlue, radius: 10)

                    Text("Enter your email to receive reset instructions")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)

                // Email Field
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(neonBlue.opacity(0.95))
                        .frame(width: 22)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .focused($emailFocused)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(emailFocused ? neonBlue : .white.opacity(0.25), lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
                )
                .shadow(color: (emailFocused ? neonBlue : .clear).opacity(0.6), radius: 8)
                .padding(.horizontal, 30)
                .disabled(isLoading)

                // Success/Error Messages
                if let successMessage = successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 30)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 30)
                        .multilineTextAlignment(.center)
                }

                // Reset Button
                Button(action: resetPassword) {
                    ZStack {
                        Text("SEND RESET EMAIL")
                            .font(.headline)
                            .tracking(2)
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
                .padding(.horizontal, 30)
                .disabled(isLoading)

                // Back to Sign In
                Button("Back to Sign In") {
                    NotificationCenter.default.post(name: .showSignIn, object: nil)
                }
                .font(.footnote)
                .foregroundColor(neonBlue)
                .padding(.top, 10)
                .disabled(isLoading)

                Spacer()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func resetPassword() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }

        successMessage = nil
        errorMessage = nil
        isLoading = true

        Task {
            do {
                // Use Supabase password reset
                try await SupabaseService.shared.client.auth.resetPasswordForEmail(email)

                await MainActor.run {
                    successMessage = "Check your email for reset instructions"
                    isLoading = false

                    // Auto-return to sign in after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        NotificationCenter.default.post(name: .showSignIn, object: nil)
                    }
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
