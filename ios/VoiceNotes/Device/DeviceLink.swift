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
    var moods: [Int] = []
    var dirty: UInt32 = 0
    var iconHash: UInt32?

    init?(_ text: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "hello", lines.count >= 3 else { return nil }
        battery = Int(lines[1]) ?? 0
        firmware = lines[2]
        year = lines.count > 3 ? Int(lines[3]) ?? 0 : 0
        month = lines.count > 4 ? Int(lines[4]) ?? 0 : 0
        day = lines.count > 5 ? Int(lines[5]) ?? 0 : 0
        let raw = lines.count > 6 ? lines[6] : ""
        if raw.count == PageEncoder.maxDays, raw.allSatisfy(\.isNumber) {
            moods = raw.map { Int(String($0)) ?? 0 }
        }
        dirty = lines.count > 7 ? UInt32(lines[7]) ?? 0 : 0
        iconHash = lines.count > 8 ? UInt32(lines[8]) : nil
    }

    var hasPage: Bool {
        year > 0 && month > 0 && day > 0 && moods.count == PageEncoder.maxDays
    }

    var dirtyDays: [Int] {
        (1...PageEncoder.maxDays).filter { dirty & (1 << ($0 - 1)) != 0 }
    }
}

@Observable
final class DeviceLink {
    static let deviceName = "VoiceNote"

    private(set) var isConnected = false
    private(set) var battery: Int?
    private(set) var firmware: String?
    private(set) var lastHelloAt: Date?
    private(set) var isRecording = false
    private(set) var pendingReset = false
    private(set) var deviceIconHash: UInt32?
    var lastError: String?

    var onRecordingFinished: ((Note) -> Void)?

    var iconsInSync: Bool {
        deviceIconHash == icons.hash
    }

    private enum Outbound: Equatable {
        case time
        case page
        case icons
        case mood(day: Int)
    }

    private let ble = EasyBLE()
    private let context: ModelContext
    private let icons: MoodIconStore
    private var outgoing: [(kind: Outbound, data: Data)] = []
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

    func moodChanged(_ mood: Int, for dayKey: String) {
        guard isConnected else { return }
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        guard parts.count == 3, parts[0] == now.year, parts[1] == now.month else { return }
        enqueue(.mood(day: parts[2]), PageEncoder.mood(year: parts[0], month: parts[1], day: parts[2], mood: mood))
    }

    func iconsChanged() {
        if isConnected {
            pushIcons()
        }
    }

    func resetDevice() {
        if isConnected {
            pendingReset = false
            pushAll(force: true)
        } else {
            pendingReset = true
        }
    }

    private func connected() {
        isConnected = true
        enqueue(.time, PageEncoder.time())
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
        deviceIconHash = hello.iconHash
        if pendingReset {
            pendingReset = false
            pushAll(force: true)
            return
        }
        reconcile(hello)
        if !iconsInSync {
            pushIcons()
        }
    }

    private func reconcile(_ hello: DeviceHello) {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let today = calendar.component(.day, from: now)
        if hello.hasPage {
            for day in hello.dirtyDays {
                context.setMood(hello.moods[day - 1], for: DayKey.make(year: hello.year, month: hello.month, day: day))
            }
            if hello.dirty == 0, hello.year == year, hello.month == month, hello.day == today,
               hello.moods == context.moods(year: year, month: month) {
                return
            }
        }
        pushPage()
    }

    private func pushAll(force: Bool) {
        enqueue(.time, PageEncoder.time())
        pushIcons()
        pushPage(force: force)
    }

    private func pushPage(force: Bool = false) {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let today = calendar.component(.day, from: now)
        let moods = context.moods(year: year, month: month)
        enqueue(.page, PageEncoder.page(year: year, month: month, today: today, moods: moods, force: force, now: now, calendar: calendar))
    }

    private func pushIcons() {
        enqueue(.icons, icons.hasOverrides ? PageEncoder.icons(icons.deviceSet) : PageEncoder.iconsReset())
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
            if sent.kind == .icons, ok {
                deviceIconHash = icons.hash
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
