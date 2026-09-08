import Foundation
import Security

enum AIProviderCredential: String, CaseIterable {
    case gemini
    case openAI
    case deepInfra
    case novita
    case hyperbolic

    var legacyDefaultsKey: String { "\(rawValue)APIKey" }
}

enum APIKeyStore {
    static let didChangeNotification = Notification.Name("CinemaAPIKeyStoreDidChange")
    private static let service = "com.matsushibadenki.Cinema.ai-provider"

    static func value(for provider: AIProviderCredential) -> String {
        var query = baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    @discardableResult
    static func set(_ value: String, for provider: AIProviderCredential) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = baseQuery(for: provider)
        let status: OSStatus
        if trimmed.isEmpty {
            let deletionStatus = SecItemDelete(query as CFDictionary)
            status = deletionStatus == errSecItemNotFound ? errSecSuccess : deletionStatus
        } else {
            let data = Data(trimmed.utf8)
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus == errSecItemNotFound {
                var insertion = query
                insertion[kSecValueData as String] = data
                insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
                status = SecItemAdd(insertion as CFDictionary, nil)
            } else {
                status = updateStatus
            }
        }
        if status == errSecSuccess {
            NotificationCenter.default.post(name: didChangeNotification, object: provider)
        }
        return status == errSecSuccess
    }

    static func migrateLegacyDefaults(_ defaults: UserDefaults = .standard) {
        for provider in AIProviderCredential.allCases {
            if !value(for: provider).isEmpty {
                defaults.removeObject(forKey: provider.legacyDefaultsKey)
                continue
            }
            guard let legacyValue = defaults.string(forKey: provider.legacyDefaultsKey),
                  !legacyValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  set(legacyValue, for: provider) else { continue }
            defaults.removeObject(forKey: provider.legacyDefaultsKey)
        }
    }

    private static func baseQuery(for provider: AIProviderCredential) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: provider.rawValue]
    }
}
