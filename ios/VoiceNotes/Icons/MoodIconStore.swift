import Foundation
import Observation
import UIKit

@Observable
final class MoodIconStore {
    private(set) var overrides: [[UInt8]?] = Array(repeating: nil, count: MoodIcons.count)
    @ObservationIgnored private let imageCache = NSCache<NSNumber, UIImage>()

    func image(for mood: Int) -> UIImage? {
        guard let bitmap = glyph(for: mood) else { return nil }
        let key = NSNumber(value: mood)
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let image = BitmapConverter.image(from: bitmap) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("mood_icons.bin")
    }

    init() {
        imageCache.countLimit = MoodIcons.count
        load()
    }

    var hasOverrides: Bool {
        overrides.contains { $0 != nil }
    }

    func glyph(for mood: Int) -> [UInt8]? {
        guard (1...MoodIcons.count).contains(mood) else { return nil }
        return overrides[mood - 1] ?? MoodIcons.defaults[mood - 1]
    }

    func isCustom(_ mood: Int) -> Bool {
        guard (1...MoodIcons.count).contains(mood) else { return false }
        return overrides[mood - 1] != nil
    }

    func setOverride(_ bitmap: [UInt8]?, for mood: Int) {
        guard (1...MoodIcons.count).contains(mood) else { return }
        overrides[mood - 1] = bitmap
        imageCache.removeObject(forKey: NSNumber(value: mood))
        save()
    }

    func resetAll() {
        overrides = Array(repeating: nil, count: MoodIcons.count)
        imageCache.removeAllObjects()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), data.count == MoodIcons.count * (MoodIcons.bytesPerIcon + 1) else {
            return
        }
        let bytes = Array(data)
        var result: [[UInt8]?] = []
        for i in 0..<MoodIcons.count {
            let start = i * (MoodIcons.bytesPerIcon + 1)
            let present = bytes[start] == 1
            let icon = Array(bytes[(start + 1)..<(start + 1 + MoodIcons.bytesPerIcon)])
            result.append(present ? icon : nil)
        }
        overrides = result
    }

    private func save() {
        var data = Data()
        for icon in overrides {
            data.append(icon == nil ? 0 : 1)
            data.append(contentsOf: icon ?? [UInt8](repeating: 0, count: MoodIcons.bytesPerIcon))
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
