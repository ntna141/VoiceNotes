import AVFoundation
import Synchronization
import UIKit

nonisolated final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    static let shared = CameraSession()

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.ntna.VoiceNotes.camera")
    private let captures = Mutex<[Int64: CheckedContinuation<UIImage?, Never>]>([:])
    private var input: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var configured = false

    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    func prewarm() {
        guard Self.isAuthorized else { return }
        queue.async { self.configure() }
    }

    func start() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard Self.isAuthorized else { return false }
        return await withCheckedContinuation { continuation in
            queue.async {
                self.configure()
                guard self.input != nil else {
                    continuation.resume(returning: false)
                    return
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: true)
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func flip() {
        queue.async {
            self.position = self.position == .back ? .front : .back
            self.session.beginConfiguration()
            self.attachInput()
            self.session.commitConfiguration()
        }
    }

    func setFlash(_ mode: AVCaptureDevice.FlashMode) {
        queue.async {
            self.flashMode = mode
        }
    }

    func capture() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning, self.output.connection(with: .video) != nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings()
                if self.output.supportedFlashModes.contains(self.flashMode) {
                    settings.flashMode = self.flashMode
                }
                self.captures.withLock { $0[settings.uniqueID] = continuation }
                self.output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let continuation = captures.withLock { $0.removeValue(forKey: photo.resolvedSettings.uniqueID) }
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        continuation?.resume(returning: image?.downscaled(maxSide: 1536))
    }

    private func configure() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        attachInput()
        session.commitConfiguration()
        configured = input != nil
    }

    private func attachInput() {
        if let input {
            session.removeInput(input)
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let next = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(next)
        else { return }
        session.addInput(next)
        input = next
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}
