import AVFoundation
import Observation

@Observable
final class MicRecorder {
    private(set) var isRecording = false

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var fileName: String?

    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let name = AudioStore.newFileName()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: AudioStore.url(for: name), settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ])
            guard recorder.record() else {
                AudioStore.remove(name)
                return false
            }
            self.recorder = recorder
            fileName = name
            isRecording = true
            return true
        } catch {
            AudioStore.remove(name)
            return false
        }
    }

    func stop() -> (fileName: String, duration: Double)? {
        guard let recorder, let fileName else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        self.fileName = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (fileName, duration)
    }
}
