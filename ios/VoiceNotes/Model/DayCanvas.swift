import Foundation
import SwiftData
import SwiftUI

nonisolated enum CanvasPage {
    static let size = CGSize(width: 360, height: 640)
    static let space = "canvas-page"
    static let padding: CGFloat = 6
    static let minWidth: CGFloat = 40
    static let maxWidth: CGFloat = 540

    static func clampWidth(_ width: Double) -> Double {
        min(max(width, minWidth), maxWidth)
    }

    static func fitted(in available: CGSize) -> CGSize {
        let fit = min(available.width / size.width, available.height / size.height)
        guard fit.isFinite, fit > 0 else { return .zero }
        return CGSize(width: size.width * fit, height: size.height * fit)
    }
}

enum CanvasPaper: Int, CaseIterable, Identifiable {
    case cream
    case white
    case yellow
    case pink
    case green
    case blue
    case lilac

    var id: Int { rawValue }

    var color: Color {
        switch self {
        case .cream: Neo.paper
        case .white: Neo.card
        case .yellow: Neo.yellow
        case .pink: Neo.redSoft
        case .green: Neo.greenSoft
        case .blue: Color(red: 0.80, green: 0.88, blue: 1.0)
        case .lilac: Color(red: 0.90, green: 0.84, blue: 1.0)
        }
    }
}

enum CanvasPattern: Int, CaseIterable, Identifiable {
    case plain
    case lines
    case dots

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .plain: "Plain"
        case .lines: "Lines"
        case .dots: "Dots"
        }
    }
}

@Model
final class DayCanvas {
    #Unique<DayCanvas>([\.dayKey])
    #Index<DayCanvas>([\.dayKey])

    var dayKey: String = ""
    var paperRaw: Int = 0
    var patternRaw: Int = 0
    var updatedAt: Date = Date()

    init(dayKey: String) {
        self.dayKey = dayKey
        self.updatedAt = Date()
    }

    var paper: CanvasPaper {
        get { CanvasPaper(rawValue: paperRaw) ?? .cream }
        set {
            paperRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var pattern: CanvasPattern {
        get { CanvasPattern(rawValue: patternRaw) ?? .plain }
        set {
            patternRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}

@Model
final class CanvasItem {
    #Index<CanvasItem>([\.dayKey])

    var id: UUID = UUID()
    var dayKey: String = ""
    var fileName: String = ""
    var cutoutFileName: String?
    var x: Double = 0
    var y: Double = 0
    var width: Double = 0
    var aspect: Double = 1
    var cutoutAspect: Double = 1
    var rotation: Double = 0
    var z: Int = 0
    var isCutout: Bool = false
    var isPlaced: Bool = true
    var createdAt: Date = Date()

    init(dayKey: String, fileName: String, aspect: Double, z: Int) {
        self.id = UUID()
        self.dayKey = dayKey
        self.fileName = fileName
        self.aspect = aspect
        self.z = z
        self.createdAt = Date()
    }

    var displayFileName: String {
        isCutout ? (cutoutFileName ?? fileName) : fileName
    }

    var displayAspect: Double {
        isCutout ? cutoutAspect : aspect
    }

    var fileNames: [String] {
        [fileName] + (cutoutFileName.map { [$0] } ?? [])
    }

    func setCutout(fileName: String, aspect: Double) {
        cutoutFileName = fileName
        cutoutAspect = aspect
        isCutout = true
    }

    func frameSize(width: Double) -> CGSize {
        let inset = isCutout ? 0 : CanvasPage.padding * 2
        let aspect = displayAspect.isFinite && displayAspect > 0 ? displayAspect : 1
        return CGSize(width: width + inset, height: width / aspect + inset)
    }

    func scatter(spread: CGSize) {
        let aspect = displayAspect
        width = aspect >= 1 ? 200 : 200 * aspect
        x = CanvasPage.size.width / 2 + .random(in: -spread.width...spread.width)
        y = CanvasPage.size.height / 2 + .random(in: -spread.height...spread.height)
        rotation = .random(in: -0.12...0.12)
    }
}

extension ModelContext {
    func canvas(for dayKey: String) -> DayCanvas {
        var descriptor = FetchDescriptor<DayCanvas>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        if let existing = (try? fetch(descriptor))?.first {
            return existing
        }
        let canvas = DayCanvas(dayKey: dayKey)
        insert(canvas)
        return canvas
    }

    func nextZ(for dayKey: String) -> Int {
        let descriptor = FetchDescriptor<CanvasItem>(predicate: #Predicate { $0.dayKey == dayKey })
        return ((try? fetch(descriptor))?.map(\.z).max() ?? 0) + 1
    }

    func addCanvasItem(dayKey: String, source: UIImage, cutout: UIImage?, spread: CGSize) async -> CanvasItem? {
        guard let fileName = await PhotoStore.save(source, cutout: false) else { return nil }
        let item = CanvasItem(dayKey: dayKey, fileName: fileName, aspect: source.size.width / source.size.height, z: nextZ(for: dayKey))
        if let cutout, let cutoutName = await PhotoStore.save(cutout, cutout: true) {
            item.setCutout(fileName: cutoutName, aspect: cutout.size.width / cutout.size.height)
        }
        item.scatter(spread: spread)
        insert(item)
        return item
    }

    func importSharedPhotos() async {
        let pending = CanvasInbox.pending()
        guard !pending.isEmpty else { return }
        for (dayKey, url) in pending {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                await addCanvasItem(dayKey: dayKey, source: image.downscaled(maxSide: 1536), cutout: nil, spread: CGSize(width: 80, height: 180))
            }
            try? FileManager.default.removeItem(at: url)
        }
        try? save()
    }
}
