import BackgroundTasks
import Foundation
import Observation
import SwiftData
import UIKit

@Observable
final class TranscriptionService {
    static let refreshTaskId = "com.ntna.VoiceNotes.transcription.refresh"
    static let processingTaskId = "com.ntna.VoiceNotes.transcription.process"
    private static let sessionId = "com.ntna.VoiceNotes.soniox"

    private(set) var activeCount = 0

    private let context: ModelContext
    private let settings: AppSettings
    private var session: URLSession!
    private var pollers: [UUID: Task<Void, Never>] = [:]
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var finishEventsHandler: (() -> Void)?

    init(context: ModelContext, settings: AppSettings) {
        self.context = context
        self.settings = settings
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        let delegate = BackgroundSessionDelegate(
            onComplete: { result in
                Task { @MainActor in
                    TranscriptionService.shared?.taskCompleted(result)
                }
            },
            onFinishEvents: {
                Task { @MainActor in
                    TranscriptionService.shared?.backgroundEventsFinished()
                }
            }
        )
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        Self.shared = self
    }

    private(set) static var shared: TranscriptionService?

    private var client: SonioxClient {
        SonioxClient(apiKey: settings.apiKey)
    }

    private var uploadsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Uploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func enqueue(_ note: Note) {
        startUpload(note)
    }

    func retry(_ note: Note) {
        cleanupRemote(note)
        note.sonioxFileId = nil
        note.sonioxTranscriptionId = nil
        note.errorMessage = nil
        startUpload(note)
    }

    func resumePending() {
        guard !fetchPending().isEmpty else { return }
        Task {
            let inFlight = Set(await session.allTasks.compactMap(\.taskDescription))
            for note in fetchPending() {
                switch note.transcription {
                case .queued:
                    startUpload(note)
                case .uploading:
                    let id = note.id.uuidString
                    if inFlight.contains("upload:\(id)") || inFlight.contains("create:\(id)") {
                        continue
                    }
                    if note.sonioxFileId != nil {
                        startCreate(note)
                    } else {
                        startUpload(note)
                    }
                case .transcribing:
                    startPolling(note)
                default:
                    break
                }
            }
        }
    }

    func setBackgroundEventsHandler(_ handler: @escaping () -> Void) {
        finishEventsHandler = handler
    }

    func registerBackgroundTasks() {
        for id in [Self.refreshTaskId, Self.processingTaskId] {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
                Task { @MainActor in
                    TranscriptionService.shared?.handleBackgroundTask(task)
                }
            }
        }
    }

    func appDidEnterBackground() {
        guard !pollers.isEmpty else {
            scheduleBackgroundRefreshIfNeeded()
            return
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "transcription-poll") { [weak self] in
            Task { @MainActor in
                self?.suspendPolling()
            }
        }
    }

    func appWillEnterForeground() {
        endBackgroundTask()
        resumePending()
    }

    private func suspendPolling() {
        for poller in pollers.values {
            poller.cancel()
        }
        pollers.removeAll()
        activeCount = 0
        scheduleBackgroundRefreshIfNeeded()
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func scheduleBackgroundRefreshIfNeeded() {
        guard !fetchPending().isEmpty else { return }
        let refresh = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
        refresh.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        try? BGTaskScheduler.shared.submit(refresh)
        let processing = BGProcessingTaskRequest(identifier: Self.processingTaskId)
        processing.requiresNetworkConnectivity = true
        processing.requiresExternalPower = false
        processing.earliestBeginDate = Date(timeIntervalSinceNow: 120)
        try? BGTaskScheduler.shared.submit(processing)
    }

    private func handleBackgroundTask(_ task: BGTask) {
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.suspendPolling()
                task.setTaskCompleted(success: false)
            }
        }
        resumePending()
        Task { @MainActor in
            while !pollers.isEmpty {
                try? await Task.sleep(for: .seconds(1))
            }
            scheduleBackgroundRefreshIfNeeded()
            task.setTaskCompleted(success: true)
        }
    }

    private func startUpload(_ note: Note) {
        guard let fileName = note.audioFileName else {
            fail(note, "No audio file")
            return
        }
        do {
            let (request, boundary) = try client.uploadRequest()
            let body = uploadsDirectory.appendingPathComponent("\(note.id.uuidString).multipart")
            try SonioxClient.writeMultipart(wav: AudioStore.url(for: fileName), boundary: boundary, to: body)
            let task = session.uploadTask(with: request, fromFile: body)
            task.taskDescription = "upload:\(note.id.uuidString)"
            note.transcription = .uploading
            note.errorMessage = nil
            try? context.save()
            task.resume()
        } catch {
            fail(note, error.localizedDescription)
        }
    }

    private func startCreate(_ note: Note) {
        guard let fileId = note.sonioxFileId else {
            startUpload(note)
            return
        }
        do {
            let (request, json) = try client.createRequest(
                fileId: fileId,
                terms: settings.vocabularyTerms,
                languageHints: settings.languageHintList,
                reference: note.id.uuidString
            )
            let body = uploadsDirectory.appendingPathComponent("\(note.id.uuidString).json")
            try json.write(to: body, options: .atomic)
            let task = session.uploadTask(with: request, fromFile: body)
            task.taskDescription = "create:\(note.id.uuidString)"
            note.transcription = .uploading
            try? context.save()
            task.resume()
        } catch {
            fail(note, error.localizedDescription)
        }
    }

    private func taskCompleted(_ result: BackgroundTaskResult) {
        let parts = result.description.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]), let note = fetchNote(id) else { return }
        let ext = parts[0] == "upload" ? "multipart" : "json"
        try? FileManager.default.removeItem(at: uploadsDirectory.appendingPathComponent("\(id.uuidString).\(ext)"))
        if let error = result.error {
            fail(note, error)
            return
        }
        guard let code = result.statusCode, (200..<300).contains(code) else {
            fail(note, SonioxError.http(result.statusCode ?? 0, SonioxClient.parseError(result.body) ?? "").localizedDescription)
            return
        }
        guard let newId = SonioxClient.parseId(result.body) else {
            fail(note, "Unexpected response")
            return
        }
        if parts[0] == "upload" {
            note.sonioxFileId = newId
            try? context.save()
            startCreate(note)
        } else {
            note.sonioxTranscriptionId = newId
            note.transcription = .transcribing
            try? context.save()
            startPolling(note)
        }
    }

    private func backgroundEventsFinished() {
        finishEventsHandler?()
        finishEventsHandler = nil
    }

    private func startPolling(_ note: Note) {
        let id = note.id
        guard pollers[id] == nil, let transcriptionId = note.sonioxTranscriptionId else { return }
        activeCount = pollers.count + 1
        pollers[id] = Task { [weak self] in
            var delay: Double = 2
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    switch try await self.client.status(transcriptionId: transcriptionId) {
                    case .completed:
                        let text = try await self.client.transcript(transcriptionId: transcriptionId)
                        self.complete(note, text: text)
                        return
                    case .error(let message):
                        self.fail(note, message)
                        return
                    case .queued:
                        break
                    }
                } catch {
                    switch error {
                    case SonioxError.missingAPIKey, SonioxError.http(401, _), SonioxError.http(404, _):
                        self.fail(note, error.localizedDescription)
                        return
                    default:
                        break
                    }
                }
                try? await Task.sleep(for: .seconds(delay))
                delay = min(delay + 1, 5)
            }
        }
    }

    private func complete(_ note: Note, text: String) {
        pollers[note.id] = nil
        activeCount = pollers.count
        note.setTranscript(text.isEmpty ? "Voice note" : text)
        note.transcription = .done
        note.errorMessage = nil
        try? context.save()
        cleanupRemote(note)
    }

    private func cleanupRemote(_ note: Note) {
        let client = self.client
        let transcriptionId = note.sonioxTranscriptionId
        let fileId = note.sonioxFileId
        guard transcriptionId != nil || fileId != nil else { return }
        Task {
            if let transcriptionId {
                await client.delete(transcriptionId: transcriptionId)
            }
            if let fileId {
                await client.deleteFile(fileId: fileId)
            }
        }
    }

    private func fail(_ note: Note, _ message: String) {
        pollers[note.id] = nil
        activeCount = pollers.count
        note.transcription = .failed
        note.errorMessage = message
        try? context.save()
    }

    private func fetchNote(_ id: UUID) -> Note? {
        var descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchPending() -> [Note] {
        let states = [TranscriptionState.queued, .uploading, .transcribing].map(\.rawValue)
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { states.contains($0.transcriptionRaw) })
        return (try? context.fetch(descriptor)) ?? []
    }
}
