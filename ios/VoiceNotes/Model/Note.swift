import Foundation
import SwiftData

enum TranscriptionState: String, Codable, Sendable {
    case none
    case recording
    case queued
    case uploading
    case transcribing
    case done
    case failed

    var isPending: Bool {
        switch self {
        case .queued, .uploading, .transcribing:
            return true
        case .none, .recording, .done, .failed:
            return false
        }
    }
}

@Model
final class Note {
    #Index<Note>([\.dayKey], [\.createdAt])

    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dayKey: String = ""
    var title: String = ""
    var body: String = ""
    var audioFileName: String?
    var durationSeconds: Double?
    var transcriptionRaw: String = TranscriptionState.none.rawValue
    var sonioxFileId: String?
    var sonioxTranscriptionId: String?
    var errorMessage: String?

    init(createdAt: Date = Date(), title: String = "", body: String = "", audioFileName: String? = nil, transcription: TranscriptionState = .none) {
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.dayKey = DayKey.make(createdAt)
        self.audioFileName = audioFileName
        self.transcriptionRaw = transcription.rawValue
        self.title = title
        self.body = body
    }

    var transcription: TranscriptionState {
        get { TranscriptionState(rawValue: transcriptionRaw) ?? .none }
        set { transcriptionRaw = newValue.rawValue }
    }

    var hasAudio: Bool {
        audioFileName != nil
    }

    var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        switch transcription {
        case .recording:
            return "Recording…"
        case .queued, .uploading, .transcribing:
            return "Voice note"
        case .failed:
            return "Voice note"
        case .none, .done:
            return "New Note"
        }
    }

    var preview: String {
        switch transcription {
        case .recording:
            return "Recording from device"
        case .queued:
            return "Waiting to upload"
        case .uploading:
            return "Uploading…"
        case .transcribing:
            return "Transcribing…"
        case .failed:
            return errorMessage.map { "Failed: \($0)" } ?? "Transcription failed"
        case .none, .done:
            let line = body.split(separator: "\n", omittingEmptySubsequences: true).first.map {
                String($0).trimmingCharacters(in: .whitespaces)
            } ?? ""
            return line.isEmpty ? "No additional text" : line
        }
    }

    var clipboardText: String {
        [title, body].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    func setTranscript(_ text: String) {
        body = body.isEmpty ? text : body + "\n\n" + text
        if title.isEmpty {
            let firstLine = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? text
            let sentence = firstLine.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? firstLine
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            title = trimmed.count > 60 ? String(trimmed.prefix(57)).trimmingCharacters(in: .whitespaces) + "…" : trimmed
        }
        updatedAt = Date()
    }
}
