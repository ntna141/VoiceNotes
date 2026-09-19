import CoreGraphics
import UIKit

enum BitmapConverter {
    enum Mode: String, CaseIterable, Identifiable {
        case dither
        case threshold
        case outline

        var id: String { rawValue }

        var label: String {
            switch self {
            case .dither: return "Dither"
            case .threshold: return "Threshold"
            case .outline: return "Outline"
            }
        }
    }

    static func bitmap(from image: UIImage, mode: Mode) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let size = MoodIcons.size
        let scale = 4
        let src = size * scale
        var pixels = [UInt8](repeating: 255, count: src * src * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress,
                width: src,
                height: src,
                bitsPerComponent: 8,
                bytesPerRow: src * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: src, height: src))
            ctx.interpolationQuality = .high
            let aspect = CGFloat(cg.width) / CGFloat(cg.height)
            var rect = CGRect(x: 0, y: 0, width: src, height: src)
            if aspect > 1 {
                rect.size.height = CGFloat(src) / aspect
                rect.origin.y = (CGFloat(src) - rect.height) / 2
            } else if aspect < 1 {
                rect.size.width = CGFloat(src) * aspect
                rect.origin.x = (CGFloat(src) - rect.width) / 2
            }
            ctx.draw(cg, in: rect)
            return true
        }
        guard drawn else { return nil }

        var hi = [Double](repeating: 0, count: src * src)
        for i in 0..<(src * src) {
            let p = i * 4
            let luma = Double(pixels[p]) * 0.299 + Double(pixels[p + 1]) * 0.587 + Double(pixels[p + 2]) * 0.114
            let alpha = Double(pixels[p + 3]) / 255
            hi[i] = (255 - luma) * alpha
        }

        var gray = [Double](repeating: 0, count: size * size)
        for row in 0..<size {
            for col in 0..<size {
                var sum = 0.0
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        sum += hi[(row * scale + dy) * src + col * scale + dx]
                    }
                }
                gray[row * size + col] = sum / Double(scale * scale)
            }
        }

        let edges = mode == .outline ? edgeStrength(hi, src: src, scale: scale, size: size) : nil
        let edgeCut = max(40, (edges?.max() ?? 0) * 0.25)

        var packed = [UInt8](repeating: 0, count: MoodIcons.bytesPerIcon)
        let stride = (size + 7) / 8
        for row in 0..<size {
            for col in 0..<size {
                let i = row * size + col
                let old = gray[i]
                let ink = edges.map { $0[i] >= edgeCut } ?? (old >= 128)
                if ink {
                    packed[row * stride + col / 8] |= 1 << UInt8(7 - (col % 8))
                }
                guard mode == .dither else { continue }
                let err = old - (ink ? 255 : 0)
                if col + 1 < size {
                    gray[i + 1] += err * 7 / 16
                }
                if row + 1 < size {
                    if col > 0 {
                        gray[i + size - 1] += err * 3 / 16
                    }
                    gray[i + size] += err * 5 / 16
                    if col + 1 < size {
                        gray[i + size + 1] += err * 1 / 16
                    }
                }
            }
        }
        return packed
    }

    private static func edgeStrength(_ hi: [Double], src: Int, scale: Int, size: Int) -> [Double] {
        var cells = [Double](repeating: 0, count: size * size)
        for y in 1..<(src - 1) {
            for x in 1..<(src - 1) {
                let p = { (dx: Int, dy: Int) in hi[(y + dy) * src + x + dx] }
                let gx = p(1, -1) + 2 * p(1, 0) + p(1, 1) - p(-1, -1) - 2 * p(-1, 0) - p(-1, 1)
                let gy = p(-1, 1) + 2 * p(0, 1) + p(1, 1) - p(-1, -1) - 2 * p(0, -1) - p(1, -1)
                let c = (y / scale) * size + x / scale
                cells[c] = max(cells[c], (gx * gx + gy * gy).squareRoot())
            }
        }
        return cells
    }

    static func image(from bitmap: [UInt8]) -> UIImage? {
        let size = MoodIcons.size
        let stride = (size + 7) / 8
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for row in 0..<size {
            for col in 0..<size {
                let ink = bitmap[row * stride + col / 8] & (1 << UInt8(7 - (col % 8))) != 0
                let i = (row * size + col) * 4
                pixels[i] = 0
                pixels[i + 1] = 0
                pixels[i + 2] = 0
                pixels[i + 3] = ink ? 255 : 0
            }
        }
        let cg = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        guard let cg else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up).withRenderingMode(.alwaysTemplate)
    }
}
