import SwiftUI

struct LockScreenView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(SettingsStore.self) private var settings

    @State private var password: String = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var l: (LKey) -> String { { L.string($0, lang: settings.appLanguage) } }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)

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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isFocused = true
            password = ""
            errorMessage = nil
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
}
