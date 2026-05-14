import Foundation
import Observation
import CryptoKit

@Observable
final class LockManager {
    private(set) var isLocked: Bool
    private(set) var isEnabled: Bool
    private(set) var contentUnlocked = false
    private(set) var unlockedGroupIDs = Set<String>()

    var hasPassword: Bool {
        UserDefaults.standard.string(forKey: Self.hashKey) != nil
    }

    init() {
        isEnabled = Self.enabledFlag()
        isLocked = false
    }

    @discardableResult
    func setPassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        let salt = Self.randomSalt()
        let hash = Self.hash(data, salt: salt)
        let d = UserDefaults.standard
        d.set(hash, forKey: Self.hashKey)
        d.set(salt, forKey: Self.saltKey)
        d.set(true, forKey: Self.enabledKey)
        isEnabled = true
        return true
    }

    func removePassword() {
        let d = UserDefaults.standard
        d.removeObject(forKey: Self.hashKey)
        d.removeObject(forKey: Self.saltKey)
        d.removeObject(forKey: "diary_lockedEntryPaths")
        d.removeObject(forKey: "diary_lockedGroupIDs")
        d.set(false, forKey: Self.enabledKey)
        isEnabled = false
        isLocked = false
        contentUnlocked = false
        unlockedGroupIDs = []
    }

    @discardableResult
    func unlock(with password: String) -> Bool {
        guard Self.verifyPassword(password) else { return false }
        isLocked = false
        contentUnlocked = true
        return true
    }

    @discardableResult
    func unlockContent(with password: String) -> Bool {
        guard Self.verifyPassword(password) else { return false }
        contentUnlocked = true
        return true
    }

    @discardableResult
    func unlockGroup(_ groupID: String, with password: String) -> Bool {
        guard Self.verifyPassword(password) else { return false }
        unlockedGroupIDs.insert(groupID)
        return true
    }

    func isGroupUnlocked(_ groupID: String) -> Bool {
        unlockedGroupIDs.contains(groupID)
    }

    func lock() {
        isLocked = true
        contentUnlocked = false
        unlockedGroupIDs = []
    }

    func verify(_ password: String) -> Bool {
        Self.verifyPassword(password)
    }

    // MARK: - Storage

    private static let enabledKey = "diary_passwordEnabled"
    private static let hashKey = "diary_passwordHash"
    private static let saltKey = "diary_passwordSalt"

    private static func enabledFlag() -> Bool {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return false }
        // Hash must exist — guards against stale flag after Keychain→UserDefaults migration
        guard UserDefaults.standard.string(forKey: hashKey) != nil else { return false }
        return true
    }

    private static func verifyPassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        let d = UserDefaults.standard
        guard let storedHash = d.string(forKey: hashKey),
              let salt = d.string(forKey: saltKey) else { return false }
        return hash(data, salt: salt) == storedHash
    }

    private static func hash(_ data: Data, salt: String) -> String {
        let salted = salt.data(using: .utf8)! + data
        let digest = SHA256.hash(data: salted)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func randomSalt() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
    }
}
