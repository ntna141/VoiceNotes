import CoreImage
import UIKit
import Vision

enum SubjectExtractor {
    @concurrent
    nonisolated static func extract(from image: UIImage) async -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg)
        guard (try? handler.perform([request])) != nil,
              let result = request.results?.first,
              let buffer = try? result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
        else { return nil }
        let masked = CIImage(cvPixelBuffer: buffer)
        guard let out = CIContext().createCGImage(masked, from: masked.extent) else { return nil }
        return UIImage(cgImage: out)
    }
}
