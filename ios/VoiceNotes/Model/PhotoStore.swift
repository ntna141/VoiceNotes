import CoreImage
import UIKit

nonisolated enum PhotoStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func remove(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    @concurrent
    static func save(_ image: UIImage, cutout: Bool) async -> String? {
        let fileName = UUID().uuidString + (cutout ? ".png" : ".jpg")
        guard let data = cutout ? image.pngData() : image.jpegData(compressionQuality: 0.85),
              (try? data.write(to: url(for: fileName), options: .atomic)) != nil
        else { return nil }
        return fileName
    }

    @concurrent
    static func load(_ fileName: String) async -> UIImage? {
        guard let image = UIImage(contentsOfFile: url(for: fileName).path) else { return nil }
        guard fileName.hasSuffix(".jpg") else { return image }
        return await image.byPreparingForDisplay() ?? image
    }

    @concurrent
    static func sticker(_ image: UIImage) async -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let source = hardened(CIImage(cgImage: cg), gain: 8)
        let side = max(source.extent.width, source.extent.height)
        let white = max(6, side * 0.025)
        let ink = white + max(2, side * 0.006)
        let shifted = source.transformed(by: CGAffineTransform(translationX: ink, y: ink))
        let inkLayer = dilated(shifted, radius: ink, color: .black)
        let whiteLayer = dilated(shifted, radius: white, color: .white)
        let composed = shifted.composited(over: whiteLayer.composited(over: inkLayer))
        let extent = CGRect(x: 0, y: 0, width: source.extent.width + ink * 2, height: source.extent.height + ink * 2)
        guard let out = CIContext().createCGImage(composed, from: extent) else { return nil }
        return UIImage(cgImage: out)
    }

    private static func hardened(_ image: CIImage, gain: CGFloat) -> CIImage {
        image
            .applyingFilter("CIUnpremultiply")
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: gain),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: -gain * 0.5 + 0.5),
            ])
            .applyingFilter("CIColorClamp")
            .applyingFilter("CIPremultiply")
            .cropped(to: image.extent)
    }

    private static func dilated(_ image: CIImage, radius: CGFloat, color: CIColor) -> CIImage {
        hardened(image, gain: 40)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: color.red),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: color.green),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: color.blue),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            ])
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])
    }
}

nonisolated extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
