import AVFoundation
import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    let mood: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(TranscriptionService.self) private var transcription
    @State private var title: String
    @State private var text: String
    @State private var player = AudioPlayer()
    @State private var copied = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var focus: Field?

    private enum Field {
        case title
        case body
    }

    init(note: Note, mood: Int) {
        self.note = note
        self.mood = mood
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.body)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            editorScroll
        }
        .background(Neo.paper.ignoresSafeArea().onTapGesture { focus = nil })
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            saveTask?.cancel()
            persist()
            player.stop()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(NeoIconButtonStyle(size: 40))
            .accessibilityLabel("Back")
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture { focus = nil }
            Button {
                persist()
                UIPasteboard.general.string = clipboardText
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(NeoIconButtonStyle(fill: copied ? Neo.green : Neo.card, size: 40))
            .disabled(clipboardText.isEmpty)
            .opacity(clipboardText.isEmpty ? 0.5 : 1)
            .accessibilityLabel(copied ? "Copied" : "Copy")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var editorScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(note.createdAt.formatted(.dateTime.month(.wide).day().year().hour().minute()))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Neo.muted)
                    if mood != 0 {
                        MoodGlyph(mood: mood, size: 16)
                    }
                    Spacer()
                    if note.hasAudio, let duration = note.durationSeconds {
                        NeoTag(text: durationText(duration), fill: Neo.card)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { focus = nil }
                TextField("Title", text: $title, axis: .vertical)
                    .font(.title.weight(.black))
                    .foregroundStyle(Neo.ink)
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .autocorrectionDisabled()
                    .onChange(of: title) { _, newValue in
                        let single = newValue.replacingOccurrences(of: "\n", with: " ")
                        if single != newValue {
                            title = single
                            focus = .body
                            scheduleSave()
                            return
                        }
                        guard single != note.title else { return }
                        scheduleSave()
                    }
                if note.hasAudio {
                    audioBar
                }
                if note.transcription.isPending || note.transcription == .failed {
                    statusChip
                }
                TextEditor(text: $text)
                    .font(.body)
                    .foregroundStyle(Neo.ink)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(minHeight: 320, alignment: .top)
                    .padding(8)
                    .focused($focus, equals: .body)
                    .neoCard(shadow: 0)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Write something…")
                                .foregroundStyle(Neo.muted)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: text) { _, newValue in
                        guard newValue != note.body else { return }
                        scheduleSave()
                    }
                    .onChange(of: note.body) { _, newValue in
                        if newValue != text {
                            text = newValue
                        }
                    }
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .contentShape(Rectangle())
                    .onTapGesture { focus = nil }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var clipboardText: String {
        [title, text].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    private func persist() {
        let nextTitle = title.replacingOccurrences(of: "\n", with: " ")
        if nextTitle != title {
            title = nextTitle
        }
        guard nextTitle != note.title || text != note.body else { return }
        note.title = nextTitle
        note.body = text
        note.updatedAt = Date()
        try? context.save()
    }

    private func goBack() {
        saveTask?.cancel()
        persist()
        focus = nil
        dismiss()
    }

    private var audioBar: some View {
        HStack(spacing: 12) {
            Button {
                if let fileName = note.audioFileName {
                    player.toggle(url: AudioStore.url(for: fileName))
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(NeoIconButtonStyle(fill: Neo.green, size: 40))
            Slider(value: Binding(get: { player.progress }, set: { player.seek(to: $0) }), in: 0...1)
                .tint(Neo.ink)
            Text(durationText(currentSeconds))
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Neo.ink)
        }
        .padding(12)
        .neoCard(Neo.redSoft)
    }

    private var currentSeconds: Double {
        let total = note.durationSeconds ?? player.duration
        return player.isPlaying || player.progress > 0 ? player.progress * total : total
    }

    private func durationText(_ seconds: Double) -> String {
        let whole = Int(seconds.rounded())
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private var statusChip: some View {
        HStack(spacing: 8) {
            if note.transcription == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(note.errorMessage ?? "Transcription failed")
                    .lineLimit(2)
                Spacer()
                Button("Retry") {
                    transcription.retry(note)
                }
                .buttonStyle(NeoButtonStyle(fill: Neo.card, shadow: 2))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(Neo.ink)
                Text(note.preview)
                Spacer()
            }
        }
        .font(.footnote.weight(.bold))
        .foregroundStyle(Neo.ink)
        .padding(12)
        .neoCard(note.transcription == .failed ? Neo.red : Neo.yellow)
    }
}

@Observable
final class AudioPlayer {
    private(set) var isPlaying = false
    private(set) var progress: Double = 0
    private(set) var duration: Double = 0

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var currentURL: URL?

    func toggle(url: URL) {
        if player == nil || currentURL != url {
            load(url)
        }
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            ticker?.cancel()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            startTicker()
        }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = fraction * player.duration
        progress = fraction
    }

    func stop() {
        player?.stop()
        ticker?.cancel()
        isPlaying = false
    }

    private func load(_ url: URL) {
        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        currentURL = url
        progress = 0
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, let player = self.player else { return }
                if player.duration > 0 {
                    self.progress = player.currentTime / player.duration
                }
                if !player.isPlaying {
                    self.isPlaying = false
                    if self.progress >= 0.99 {
                        self.progress = 0
                    }
                    return
                }
            }
        }
    }
}
