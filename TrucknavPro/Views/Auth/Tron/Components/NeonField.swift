//
//  NeonField.swift
//  TruckNavPro
//

import SwiftUI

struct NeonField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    @FocusState var focusedField: Field?
    let field: Field
    let neon: Color

    enum Field { case email, password }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(neon.opacity(0.95))
                .frame(width: 22)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
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
                .stroke(focusedField == field ? neon : .white.opacity(0.25), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.05)))
        )
        .shadow(color: (focusedField == field ? neon : .clear).opacity(0.6), radius: 8)
    }
}
