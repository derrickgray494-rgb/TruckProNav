//
//  LaunchView_Tron.swift
//  TruckNavPro
//

import SwiftUI

struct LaunchView_Tron: View {
    @State private var showSignUp = false
    @State private var showReset = false

    var body: some View {
        Group {
            if showReset {
                PasswordResetView_Tron()
                    .onReceive(NotificationCenter.default.publisher(for: .showSignIn)) { _ in
                        showReset = false
                        showSignUp = false
                    }
            } else if showSignUp {
                SignUpView_Tron()
                    .onReceive(NotificationCenter.default.publisher(for: .showSignIn)) { _ in
                        showSignUp = false
                    }
            } else {
                SignInView_Tron()
                    .onReceive(NotificationCenter.default.publisher(for: .showSignUp)) { _ in
                        showSignUp = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .showPasswordReset)) { _ in
                        showReset = true
                    }
            }
        }
    }
}
