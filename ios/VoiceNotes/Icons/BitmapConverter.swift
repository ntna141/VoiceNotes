import CoreGraphics
import UIKit

enum BitmapConverter {
    enum Mode: String, CaseIterable, Identifiable {
        case dither
        case threshold

        var id: String { rawValue }

        var label: String {
            switch self {
            case .dither: return "Dither"
            case .threshold: return "Threshold"
            }
        }
    }

    static func bitmap(from image: UIImage, mode: Mode) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let size = MoodIcons.size
        let scale = 4
        let src = size * scale
        var pixels = [UInt8](repeating: 255, count: src * src * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: src,
            height: src,
            bitsPerComponent: 8,
            bytesPerRow: src * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
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

        var gray = [Double](repeating: 0, count: size * size)
        for row in 0..<size {
            for col in 0..<size {
                var sum = 0.0
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        let i = ((row * scale + dy) * src + col * scale + dx) * 4
                        let luma = Double(pixels[i]) * 0.299 + Double(pixels[i + 1]) * 0.587 + Double(pixels[i + 2]) * 0.114
                        let alpha = Double(pixels[i + 3]) / 255
                        sum += (255 - luma) * alpha
                    }
                }
                gray[row * size + col] = sum / Double(scale * scale)
            }
        }

        var packed = [UInt8](repeating: 0, count: MoodIcons.bytesPerIcon)
        let stride = (size + 7) / 8
        for row in 0..<size {
            for col in 0..<size {
                let i = row * size + col
                let old = gray[i]
                let ink = old >= 128
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
        guard let ctx = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up).withRenderingMode(.alwaysTemplate)
    }
}
