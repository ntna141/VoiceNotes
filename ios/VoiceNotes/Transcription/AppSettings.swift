import Foundation
import Observation
import Security

@Observable
final class AppSettings {
    private static let keychainAccount = "soniox-api-key"
    private static let vocabKey = "customVocabulary"
    private static let languageKey = "languageHints"

    var apiKey: String {
        didSet { Keychain.set(apiKey, account: Self.keychainAccount) }
    }

    var customVocabulary: String {
        didSet { UserDefaults.standard.set(customVocabulary, forKey: Self.vocabKey) }
    }

    var languageHints: String {
        didSet { UserDefaults.standard.set(languageHints, forKey: Self.languageKey) }
    }

    init() {
        apiKey = Keychain.get(account: Self.keychainAccount) ?? ""
        customVocabulary = UserDefaults.standard.string(forKey: Self.vocabKey) ?? ""
        languageHints = UserDefaults.standard.string(forKey: Self.languageKey) ?? ""
    }

    func addTerm(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !vocabularyTerms.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        customVocabulary = (vocabularyTerms + [trimmed]).joined(separator: "\n")
    }

    func removeTerm(_ term: String) {
        customVocabulary = vocabularyTerms.filter { $0 != term }.joined(separator: "\n")
    }

    func addLanguage(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !languageHintList.contains(trimmed) else { return }
        languageHints = (languageHintList + [trimmed]).joined(separator: "\n")
    }

    func removeLanguage(_ code: String) {
        languageHints = languageHintList.filter { $0 != code }.joined(separator: "\n")
    }

    var vocabularyTerms: [String] {
        customVocabulary
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var languageHintList: [String] {
        languageHints
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}

enum Keychain {
    private static let service = "com.ntna.VoiceNotes"

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var insert = query
        insert[kSecValueData as String] = Data(value.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insert as CFDictionary, nil)
    }
}
