import Foundation
import Observation
import UIKit

@Observable
final class WallpaperStore {
    static let size = 200
    static let bytes = BitmapConverter.bytes(forSize: size)

    private(set) var bitmap: [UInt8]?
    @ObservationIgnored private var cachedImage: UIImage?

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("wallpaper.bin")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL), data.count == Self.bytes {
            bitmap = Array(data)
        }
    }

    var image: UIImage? {
        guard let bitmap else { return nil }
        if let cachedImage {
            return cachedImage
        }
        cachedImage = BitmapConverter.image(from: bitmap, size: Self.size)
        return cachedImage
    }

    var hash: UInt32 {
        guard let bitmap else { return 0 }
        var hash: UInt32 = 2_166_136_261
        for byte in bitmap {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash
    }

    func set(_ bitmap: [UInt8]?) {
        guard bitmap == nil || bitmap?.count == Self.bytes else { return }
        self.bitmap = bitmap
        cachedImage = nil
        if let bitmap {
            try? Data(bitmap).write(to: fileURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
