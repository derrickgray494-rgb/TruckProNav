//
//  LoginView.swift
//  TruckNavPro
//
//  Custom SwiftUI login screen with authentication

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    // MARK: - Colors
    private let accent = Color(red: 0.85, green: 0.25, blue: 0.2) // orange-red
    private let steelBlue = Color(red: 0.10, green: 0.17, blue: 0.25)

    var body: some View {
        ZStack {
            // MARK: - Background
            Image("truck_background") // User adds this to Assets
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.45)) // dark overlay for contrast

            VStack(spacing: 25) {

                Spacer().frame(height: 60)

                // MARK: - App Title
                VStack(spacing: 6) {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 55))
                        .foregroundColor(accent)
                        .shadow(color: .black.opacity(0.8), radius: 10)

                    Text("TruckNav Pro")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 10)

                    Text("Professional truck navigation built for drivers.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 40)

                // MARK: - Input Fields
                VStack(spacing: 20) {
                    CustomTextField(
                        placeholder: "Email",
                        text: $email,
                        icon: "envelope.fill"
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)

                    CustomTextField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock.fill",
                        isSecure: true
                    )
                    .textContentType(.password)
                }
                .padding(.horizontal, 30)
                .disabled(isLoading)

                // MARK: - Sign In Button
                Button(action: signIn) {
                    ZStack {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                }
                .background(LinearGradient(colors: [accent, steelBlue], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(14)
                .shadow(color: accent.opacity(0.5), radius: 8, y: 4)
                .padding(.horizontal, 30)
                .padding(.top, 10)
                .disabled(isLoading)

                // MARK: - Links
                HStack {
                    Button("Create Account") {
                        signUp()
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)
                    .disabled(isLoading)

                    Spacer()

                    Button("Forgot Password?") {
                        showForgotPassword()
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)
                    .disabled(isLoading)
                }
                .padding(.horizontal, 30)
                .padding(.top, 8)

                Spacer()

                // MARK: - Footer
                Text("© \(Calendar.current.component(.year, from: Date())) TruckNavPro. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else {
            showAlertWith(title: "Error", message: "Please enter email and password")
            return
        }

        Task {
            isLoading = true

            do {
                try await AuthManager.shared.signIn(email: email, password: password)
                print("✅ Sign in successful")
                // AuthManager updates isAuthenticated, ContentView will react
            } catch {
                await MainActor.run {
                    showAlertWith(title: "Sign In Failed", message: error.localizedDescription)
                }
                print("❌ Sign in failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func signUp() {
        guard !email.isEmpty, !password.isEmpty else {
            showAlertWith(title: "Error", message: "Please enter email and password")
            return
        }

        if password.count < 6 {
            showAlertWith(title: "Error", message: "Password must be at least 6 characters")
            return
        }

        Task {
            isLoading = true

            do {
                try await AuthManager.shared.signUp(email: email, password: password)
                print("✅ Sign up successful")
                // AuthManager updates isAuthenticated, ContentView will react
            } catch {
                await MainActor.run {
                    showAlertWith(title: "Sign Up Failed", message: error.localizedDescription)
                }
                print("❌ Sign up failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func showForgotPassword() {
        showAlertWith(
            title: "Forgot Password",
            message: "Please contact support at GitHub Issues to reset your password."
        )
    }

    private func showAlertWith(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Custom TextField Component

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    var isSecure: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.8))

            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focused ? .orange : .white.opacity(0.3), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.25))
                )
                .shadow(color: .black.opacity(0.3), radius: 5, y: 4)
        )
    }
}

#Preview {
    LoginView()
}
