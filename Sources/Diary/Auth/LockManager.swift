import Foundation
import Observation
import Security

@Observable
final class LockManager {
    private(set) var isLocked: Bool

    init() {
        isLocked = Self.readEnabledFlag() && Self.hasPassword()
    }

    var isEnabled: Bool {
        Self.readEnabledFlag() && Self.hasPassword()
    }

    @discardableResult
    func setPassword(_ password: String) -> Bool {
        guard Self.storePassword(password) else { return false }
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        return true
    }

    func removePassword() {
        Self.deletePassword()
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        isLocked = false
    }

    @discardableResult
    func unlock(with password: String) -> Bool {
        guard Self.verifyPassword(password) else { return false }
        isLocked = false
        return true
    }

    func lock() {
        isLocked = true
    }

    func verify(_ password: String) -> Bool {
        Self.verifyPassword(password)
    }

    // MARK: - Keychain

    private static let serviceName = "com.diary.app.password"
    private static let accountName = "diary"
    private static let enabledKey = "diary_passwordEnabled"

    private static func readEnabledFlag() -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    private static func hasPassword() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    private static func storePassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    private static func verifyPassword(_ password: String) -> Bool {
        guard let inputData = password.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let storedData = result as? Data else {
            return false
        }
        return storedData == inputData
    }

    private static func deletePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(query as CFDictionary)
    }
}
