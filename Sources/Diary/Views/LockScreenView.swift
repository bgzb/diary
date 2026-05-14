import SwiftUI

struct LockScreenView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(SettingsStore.self) private var settings

    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var showReset = false
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @FocusState private var isFocused: Bool

    private var l: (LKey) -> String { { L.string($0, lang: settings.appLanguage) } }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)

            if showReset {
                Text(l(.setNewPassword))
                    .font(.title2)
                    .foregroundStyle(.secondary)

                SecureField(l(.newPassword), text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                SecureField(l(.confirmPassword), text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                HStack(spacing: 12) {
                    Button(l(.cancel)) {
                        showReset = false
                        newPassword = ""
                        confirmPassword = ""
                        errorMessage = nil
                    }

                    Button(l(.setPassword)) {
                        resetPassword()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
                }
            } else {
                Text(l(.enterPassword))
                    .font(.title2)
                    .foregroundStyle(.secondary)

                SecureField(l(.enterPassword), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .focused($isFocused)
                    .onSubmit { attemptUnlock() }

                Button(l(.unlock)) {
                    attemptUnlock()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Spacer()

            if !showReset {
                Button(l(.forgotPassword)) {
                    showReset = true
                    errorMessage = nil
                }
                .buttonStyle(.link)
                .font(.caption)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isFocused = true
            password = ""
            errorMessage = nil
            showReset = false
            newPassword = ""
            confirmPassword = ""
        }
    }

    private func attemptUnlock() {
        if lockManager.unlock(with: password) {
            password = ""
            errorMessage = nil
        } else {
            errorMessage = l(.incorrectPassword)
            password = ""
        }
    }

    private func resetPassword() {
        guard newPassword == confirmPassword else {
            errorMessage = l(.passwordMismatch)
            return
        }
        lockManager.setPassword(newPassword)
        lockManager.unlock(with: newPassword)
        newPassword = ""
        confirmPassword = ""
        errorMessage = nil
        showReset = false
    }
}
