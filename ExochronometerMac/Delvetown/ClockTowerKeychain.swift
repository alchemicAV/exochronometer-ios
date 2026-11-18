import Foundation
import Security

/// Thin Keychain wrapper for the SECOND delve.town account — the daily
/// clock tower. Mirrors `DelvetownKeychain` exactly (same key set, same
/// in-memory cache) but under a distinct `service`, so the clock-tower
/// account and Octavia's account audit and clear independently — the same
/// reason X and Delvetown already use separate services.
///
/// Reads are backed by an in-memory cache (keychain touched at most once per
/// key per process launch) for the same reason as Delvetown/X: under ad-hoc
/// signing every rebuild is a "new app" to the keychain ACL, so each read
/// otherwise re-prompts for the login password and the OS won't persist trust
/// across rebuilds. Writes are write-through.
enum ClockTowerKeychain {
    private static let service = "com.alchemicav.exochronometer.delvetown.clocktower"

    private static var cache: [Key: String] = [:]
    private static let cacheLock = NSLock()

    enum Key: String, CaseIterable {
        case handle            = "handle"          // e.g. clocktower.delve.town
        case appPassword       = "appPassword"     // ATProto app password
        case accessJwt         = "accessJwt"
        case refreshJwt        = "refreshJwt"
        case accessJwtExpiry   = "accessJwtExpiry" // ISO-8601 of expiry
        case did               = "did"
    }

    static func set(_ value: String?, for key: Key) {
        guard let value, !value.isEmpty else {
            delete(key)
            return
        }
        let data = Data(value.utf8)
        let q: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key.rawValue
        ]
        // Update in place rather than delete-then-add (see DelvetownKeychain
        // for the rationale): recreating the item resets its ACL and defeats
        // "Always Allow", re-prompting on every token refresh.
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(q as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = q
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }

        cacheLock.lock()
        cache[key] = value
        cacheLock.unlock()
    }

    static func get(_ key: Key) -> String? {
        cacheLock.lock()
        if let cached = cache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let str = rawGet(key) else { return nil }

        cacheLock.lock()
        cache[key] = str
        cacheLock.unlock()
        return str
    }

    private static func rawGet(_ key: Key) -> String? {
        let q: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key.rawValue,
            kSecMatchLimit as String:   kSecMatchLimitOne,
            kSecReturnData as String:   true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    static func delete(_ key: Key) {
        let q: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key.rawValue
        ]
        SecItemDelete(q as CFDictionary)

        cacheLock.lock()
        cache[key] = nil
        cacheLock.unlock()
    }

    /// Warm the cache for every key in one go. Call once at launch so all
    /// keychain prompts cluster up front rather than trickling in at the
    /// first unattended post.
    static func preload() {
        for key in Key.allCases { _ = get(key) }
    }

    static func clearAll() {
        for key in Key.allCases { delete(key) }
    }
}
