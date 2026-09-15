import EasyBLE
import Foundation
import Observation
import SwiftData
import UIKit

struct DeviceHello {
    var battery: Int
    var firmware: String
    var year: Int
    var month: Int
    var day: Int
    var mood: Int

    init?(_ text: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "hello", lines.count >= 3 else { return nil }
        battery = Int(lines[1]) ?? 0
        firmware = lines[2]
        year = lines.count > 3 ? Int(lines[3]) ?? 0 : 0
        month = lines.count > 4 ? Int(lines[4]) ?? 0 : 0
        day = lines.count > 5 ? Int(lines[5]) ?? 0 : 0
        mood = lines.count > 6 ? Int(lines[6]) ?? 0 : 0
    }

    var dayKey: String? {
        guard year > 0, month > 0, day > 0 else { return nil }
        return DayKey.make(year: year, month: month, day: day)
    }
}

@Observable
final class DeviceLink {
    static let deviceName = "VoiceNote"
    private static let lastSentDayKey = "lastSentTodayMood.dayKey"
    private static let lastSentMoodKey = "lastSentTodayMood.value"

    private(set) var isConnected = false
    private(set) var battery: Int?
    private(set) var firmware: String?
    private(set) var lastHelloAt: Date?
    private(set) var isRecording = false
    private(set) var pendingReset = false
    var lastError: String?

    var onRecordingFinished: ((Note) -> Void)?

    private let ble = EasyBLE()
    private let context: ModelContext
    private let icons: MoodIconStore
    private var outgoing: [(EasyBLEMessageType, Data)] = []
    private var recordingTask: Task<Void, Never>?
    private var activeChannel: EasyBLEIncomingChannel?

    init(context: ModelContext, icons: MoodIconStore) {
        self.context = context
        self.icons = icons
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

    func moodsChanged() {
        if isConnected {
            pushPage()
        }
    }

    func iconsChanged() {
        if isConnected {
            pushIcons()
        }
    }

    func resetMoodsOnDevice() {
        if isConnected {
            pushPage()
            pendingReset = false
        } else {
            pendingReset = true
        }
    }

    private func connected() {
        isConnected = true
        enqueue(.image, PageEncoder.time())
        if icons.hasOverrides || !icons.deviceInSync {
            pushIcons()
        }
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
        if pendingReset {
            pendingReset = false
        } else {
            reconcile(hello)
        }
        pushPage()
    }

    private func reconcile(_ hello: DeviceHello) {
        guard hello.mood != 0, let dayKey = hello.dayKey, dayKey == DayKey.today else { return }
        let defaults = UserDefaults.standard
        let lastDay = defaults.string(forKey: Self.lastSentDayKey)
        let lastMood = defaults.integer(forKey: Self.lastSentMoodKey)
        if lastDay == dayKey && lastMood == hello.mood {
            return
        }
        context.setMood(hello.mood, for: dayKey)
    }

    private func pushPage() {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let today = calendar.component(.day, from: now)
        let moods = context.moods(year: year, month: month)
        enqueue(.image, PageEncoder.page(year: year, month: month, today: today, moods: moods, now: now, calendar: calendar))
        let defaults = UserDefaults.standard
        defaults.set(DayKey.today, forKey: Self.lastSentDayKey)
        defaults.set(moods[today - 1], forKey: Self.lastSentMoodKey)
    }

    private func pushIcons() {
        enqueue(.image, icons.hasOverrides ? PageEncoder.icons(icons.deviceSet) : PageEncoder.iconsReset())
        icons.markSynced()
    }

    private func enqueue(_ type: EasyBLEMessageType, _ data: Data) {
        outgoing.append((type, data))
        pump()
    }

    private func pump() {
        guard isConnected, !ble.isSending, let next = outgoing.first else { return }
        if !ble.send(next.0, data: next.1) {
            outgoing.removeFirst()
            pump()
        }
    }

    private func sendFinished(_ ok: Bool) {
        if !outgoing.isEmpty {
            outgoing.removeFirst()
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
