import EasyBLE
import Foundation
import Observation
import SwiftData
import UIKit

struct DeviceHello {
    var battery: Int
    var firmware: String
    var wallpaperHash: UInt32?
    var protocolVersion: Int?

    init?(_ text: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "hello", lines.count >= 3 else { return nil }
        battery = Int(lines[1]) ?? 0
        firmware = lines[2]
        wallpaperHash = lines.count > 3 ? UInt32(lines[3]) : nil
        protocolVersion = lines.count > 4 ? Int(lines[4]) : nil
    }
}

@Observable
final class DeviceLink {
    static let deviceName = "VoiceNote"
    static let protocolVersion = 2

    private(set) var isConnected = false
    private(set) var battery: Int?
    private(set) var firmware: String?
    private(set) var lastHelloAt: Date?
    private(set) var isRecording = false
    private(set) var pendingReset = false
    private(set) var deviceWallpaperHash: UInt32?
    var lastError: String?

    var onRecordingFinished: ((Note) -> Void)?

    var wallpaperInSync: Bool {
        deviceWallpaperHash == wallpaper.hash
    }

    private enum Outbound: Equatable {
        case time
        case wallpaper
    }

    private let ble = EasyBLE()
    private let context: ModelContext
    private let wallpaper: WallpaperStore
    private var outgoing: [(kind: Outbound, data: Data)] = []
    private var recordingTask: Task<Void, Never>?
    private var activeChannel: EasyBLEIncomingChannel?

    init(context: ModelContext, wallpaper: WallpaperStore) {
        self.context = context
        self.wallpaper = wallpaper
        ble.onConnect { [weak self] in self?.connected() }
        ble.onDisconnect { [weak self] in self?.disconnected() }
        ble.onReceive { [weak self] message in self?.received(message) }
        ble.onSendResult { [weak self] ok in self?.sendFinished(ok) }
        ble.onChannelOpen { [weak self] channel in self?.channelOffered(channel) }
    }

    func pair() async {
        do {
            let image = UIImage(named: "DeviceImage") ?? UIImage()
            try await ble.pair(name: Self.deviceName, image: image)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func unpair() async {
        do {
            try await ble.unpair()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func wallpaperChanged() {
        if isConnected {
            pushWallpaper()
        }
    }

    func resetDevice() {
        if isConnected {
            pendingReset = false
            pushAll()
        } else {
            pendingReset = true
        }
    }

    private func connected() {
        isConnected = true
        enqueue(.time, DeviceEncoder.time())
    }

    private func disconnected() {
        isConnected = false
        outgoing.removeAll()
        if let channel = activeChannel {
            channel.close()
        }
    }

    private func received(_ message: EasyBLEMessage) {
        guard message.type == .text, let hello = DeviceHello(String(decoding: message.data, as: UTF8.self)) else {
            return
        }
        battery = hello.battery
        firmware = hello.firmware
        lastHelloAt = Date()
        deviceWallpaperHash = hello.wallpaperHash
        if let version = hello.protocolVersion, version != Self.protocolVersion {
            lastError = "Device firmware \(hello.firmware) is not compatible with this app version"
            outgoing.removeAll()
            return
        }
        if pendingReset {
            pendingReset = false
            pushAll()
            return
        }
        if !wallpaperInSync && !outgoing.contains(where: { $0.kind == .wallpaper }) {
            pushWallpaper()
        }
    }

    private func pushAll() {
        enqueue(.time, DeviceEncoder.time())
        pushWallpaper()
    }

    private func pushWallpaper() {
        enqueue(.wallpaper, wallpaper.bitmap.map(DeviceEncoder.wallpaper) ?? DeviceEncoder.wallpaperReset())
    }

    private func enqueue(_ kind: Outbound, _ data: Data) {
        let inFlight = ble.isSending ? 1 : 0
        outgoing = Array(outgoing.prefix(inFlight)) + outgoing.dropFirst(inFlight).filter { $0.kind != kind }
        outgoing.append((kind, data))
        pump()
    }

    private func pump() {
        guard isConnected, !ble.isSending, let next = outgoing.first else { return }
        if !ble.send(.image, data: next.data) {
            outgoing.removeFirst()
            pump()
        }
    }

    private func sendFinished(_ ok: Bool) {
        if !outgoing.isEmpty {
            let sent = outgoing.removeFirst()
            if sent.kind == .wallpaper, ok {
                deviceWallpaperHash = wallpaper.hash
            }
        }
        if !ok {
            lastError = "Device rejected message"
        }
        pump()
    }

    private func channelOffered(_ channel: EasyBLEIncomingChannel) {
        activeChannel?.close()
        recordingTask?.cancel()
        guard let format = AudioDescriptor(channel.descriptor) else {
            channel.close()
            return
        }
        let fileName = AudioStore.newFileName()
        let writer: WAVWriter
        do {
            writer = try WAVWriter(url: AudioStore.url(for: fileName), sampleRate: format.sampleRate, channels: format.channels)
        } catch {
            lastError = error.localizedDescription
            channel.close()
            return
        }
        let note = Note(audioFileName: fileName, transcription: .recording)
        context.insert(note)
        try? context.save()
        activeChannel = channel
        isRecording = true
        let decoder = AdpcmDecoder(format: format)
        let events = channel.events
        channel.accept()
        recordingTask = Task { [weak self] in
            for await event in events {
                switch event {
                case .data(let data):
                    try? writer.write(decoder.decode(data))
                case .gap(let dropped):
                    try? writer.write(decoder.silence(droppedBytes: dropped))
                case .ended:
                    break
                }
            }
            try? writer.finish()
            self?.recordingEnded(note, duration: writer.durationSeconds)
        }
    }

    private func recordingEnded(_ note: Note, duration: Double) {
        activeChannel = nil
        isRecording = false
        note.durationSeconds = duration
        if duration < 0.3 {
            AudioStore.remove(note.audioFileName)
            context.delete(note)
            try? context.save()
            return
        }
        note.transcription = .queued
        note.updatedAt = Date()
        try? context.save()
        onRecordingFinished?(note)
    }
}
