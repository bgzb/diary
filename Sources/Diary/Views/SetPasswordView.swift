import SwiftUI

enum PasswordMode: Identifiable {
    case set
    case change
    case remove

    var id: Self { self }
}

struct SetPasswordView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let mode: PasswordMode

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?

    private var l: (LKey) -> String { { L.string($0, lang: settings.appLanguage) } }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: mode == .remove ? "lock.open" : "lock.shield")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            if mode == .change || mode == .remove {
                SecureField(l(.currentPassword), text: $currentPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if mode == .set || mode == .change {
                SecureField(l(.newPassword), text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                SecureField(l(.confirmPassword), text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button(l(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(actionTitle) {
                    performAction()
                }
                .keyboardShortcut(.return)
                .disabled(actionDisabled)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var title: String {
        switch mode {
        case .set: return l(.setPassword)
        case .change: return l(.changePassword)
        case .remove: return l(.removePassword)
        }
    }

    private var actionTitle: String {
        switch mode {
        case .set: return l(.setPassword)
        case .change: return l(.changePassword)
        case .remove: return l(.removePassword)
        }
    }

    private var actionDisabled: Bool {
        switch mode {
        case .set, .change:
            return newPassword.isEmpty || confirmPassword.isEmpty
        case .remove:
            return currentPassword.isEmpty
        }
    }

    private func performAction() {
        errorMessage = nil

        switch mode {
        case .set, .change:
            guard newPassword == confirmPassword else {
                errorMessage = l(.passwordMismatch)
                return
            }
            if mode == .change {
                guard lockManager.verify(currentPassword) else {
                    errorMessage = l(.incorrectPassword)
                    return
                }
            }
            lockManager.setPassword(newPassword)
            dismiss()

        case .remove:
            guard lockManager.verify(currentPassword) else {
                errorMessage = l(.incorrectPassword)
                return
            }
            lockManager.removePassword()
            dismiss()
        }
    }
}
