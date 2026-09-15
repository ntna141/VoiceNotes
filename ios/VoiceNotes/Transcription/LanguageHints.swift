import Foundation

struct LanguageHint: Identifiable, Hashable {
    let code: String
    var id: String { code }

    var localizedName: String {
        Locale.current.localizedString(forLanguageCode: code)
            ?? Locale(identifier: "en").localizedString(forLanguageCode: code)
            ?? code
    }

    fileprivate var names: [String] {
        [Locale.current, Locale(identifier: "en")]
            .compactMap { $0.localizedString(forLanguageCode: code)?.lowercased() }
    }

    fileprivate func matches(_ query: String) -> Bool {
        code.hasPrefix(query) || names.contains { $0.contains(query) }
    }

    fileprivate func rank(_ query: String) -> Int {
        if code == query { return 0 }
        if names.contains(query) { return 1 }
        if code.hasPrefix(query) { return 2 }
        if names.contains(where: { $0.hasPrefix(query) }) { return 3 }
        return 4
    }
}

enum LanguageHints {
    static let all: [LanguageHint] = codes.map(LanguageHint.init)

    static func displayName(for code: String) -> String {
        LanguageHint(code: code).localizedName
    }

    static func matches(_ query: String, excluding: [String] = []) -> [LanguageHint] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let skipped = Set(excluding.map { $0.lowercased() })
        return all
            .filter { !skipped.contains($0.code) && $0.matches(q) }
            .sorted { $0.rank(q) < $1.rank(q) }
    }

    static func resolve(_ query: String) -> String? {
        let found = matches(query)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = found.first(where: { $0.code == q }) { return exact.code }
        if let named = found.first(where: { $0.names.contains(q) }) { return named.code }
        if found.count == 1 { return found[0].code }
        return nil
    }

    private static let codes = [
        "af", "sq", "ar", "az", "eu", "be", "bn", "bs", "bg", "ca",
        "zh", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "gl",
        "de", "el", "gu", "he", "hi", "hu", "id", "it", "ja", "kn",
        "kk", "ko", "lv", "lt", "mk", "ms", "ml", "mr", "no", "fa",
        "pl", "pt", "pa", "ro", "ru", "sr", "sk", "sl", "es", "sw",
        "sv", "tl", "ta", "te", "th", "tr", "uk", "ur", "vi", "cy",
    ]
}
