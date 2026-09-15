import Foundation

nonisolated enum CanvasInbox {
    static let appGroup = "group.com.ntna.VoiceNotes"

    static var directory: URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let dir = base.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func store(_ data: Data, dayKey: String) -> Bool {
        guard let directory else { return false }
        let day = directory.appendingPathComponent(dayKey, isDirectory: true)
        try? FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
        return (try? data.write(to: day.appendingPathComponent(UUID().uuidString), options: .atomic)) != nil
    }

    static func pending() -> [(dayKey: String, url: URL)] {
        guard let directory, let days = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return days.flatMap { day in
            let files = (try? FileManager.default.contentsOfDirectory(at: day, includingPropertiesForKeys: [.creationDateKey])) ?? []
            if files.isEmpty {
                try? FileManager.default.removeItem(at: day)
            }
            return files.sorted { created($0) < created($1) }.map { (day.lastPathComponent, $0) }
        }
    }

    private static func created(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
