import Foundation

// Read the runtime's shared preference without changing it or opening a connection.
enum L10n {
    private static let messages: [String: [String: String]] = {
        guard let data = Data(base64Encoded: EmbeddedLocalization.encoded),
              let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return decoded
    }()
    static var languages: [String] { messages.keys.sorted() }
    private static let preferences = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PalworldMods/preferences.json")
    private static var modified: Date?
    private static var selected = normalize(Locale.preferredLanguages.first ?? "en")

    static func normalize(_ value: String) -> String {
        let tag = value.replacingOccurrences(of: "_", with: "-").lowercased()
        if let exact = languages.first(where: { $0.lowercased() == tag }) { return exact }
        if tag.hasPrefix("zh") {
            return tag.contains("hant") || ["zh-tw", "zh-hk", "zh-mo"].contains(where: { tag.hasPrefix($0) }) ? "zh-Hant" : "zh-Hans"
        }
        if tag.hasPrefix("es-"), !tag.hasPrefix("es-es") { return "es-419" }
        if tag.hasPrefix("pt") { return "pt-BR" }
        let base = tag.components(separatedBy: "-")[0]
        return languages.contains(base) ? base : "en"
    }

    static var language: String {
        // URL resource values can be cached across atomic file replacement.
        let stamp = (try? FileManager.default.attributesOfItem(atPath: preferences.path))?[.modificationDate] as? Date
        if stamp != modified {
            modified = stamp
            selected = normalize(Locale.preferredLanguages.first ?? "en")
            if let data = try? Data(contentsOf: preferences), data.count <= 4096,
               let state = try? JSONDecoder().decode([String: String].self, from: data) {
                let saved = state["language"] ?? "auto"
                let mode = languages.contains(saved) ? saved : "auto"
                selected = normalize(mode == "auto" ? state["game_language"] ?? Locale.preferredLanguages.first ?? "en" : mode)
            }
        }
        return selected
    }

    static func text(_ key: String) -> String { messages[language]?[key] ?? messages["en"]?[key] ?? key }
}
