import Foundation

enum AudioStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func newFileName() -> String {
        "\(Int(Date().timeIntervalSince1970)).wav"
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func remove(_ fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
