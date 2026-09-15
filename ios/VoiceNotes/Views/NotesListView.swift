import SwiftData
import SwiftUI

struct YearDestination: Hashable {
    let dayKey: String
}

struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(DeviceLink.self) private var link
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var moods: [DayMood]
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var path = NavigationPath()
    @FocusState private var searchFocused: Bool

    private var moodByDay: [String: Int] {
        Dictionary(uniqueKeysWithValues: moods.map { ($0.dayKey, $0.mood) })
    }

    private var filtered: [Note] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                header
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                if searchText.isEmpty {
                    MoodWeekStrip(moodByDay: moodByDay) { dayKey in
                        openYear(dayKey)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                ForEach(NoteSections.group(filtered)) { section in
                    Section {
                        ForEach(section.notes) { note in
                            Button {
                                openNote(note)
                            } label: {
                                NoteRow(note: note, mood: moodByDay[note.dayKey] ?? 0)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { offsets in
                            delete(offsets.map { section.notes[$0] })
                        }
                    } header: {
                        NeoSectionHeader(title: section.title)
                            .padding(.leading, 16)
                    }
                    .listSectionSeparator(.hidden)
                }
                if filtered.isEmpty {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 16, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(8)
            .scrollContentBackground(.hidden)
            .background(Neo.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .scrollDismissesKeyboard(.immediately)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting {
                    searchFocused = false
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    searchFocused = false
                }
            )
            .navigationDestination(for: YearDestination.self) { destination in
                YearMoodSheet(initialDayKey: destination.dayKey) { note in
                    path.append(note)
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteEditorView(note: note, mood: moodByDay[note.dayKey] ?? 0)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-show-year") {
                    openYear(DayKey.today)
                } else if args.contains("-show-settings") {
                    showSettings = true
                } else if args.contains("-show-editor"), let note = notes.first(where: { $0.hasAudio && $0.transcription == .done }) {
                    openNote(note)
                }
                #endif
            }
        }
        .tint(Neo.ink)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notes")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(Neo.ink)
                Text(subtitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Neo.muted)
            }
            Spacer()
            Button {
                searchFocused = false
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(NeoIconButtonStyle(fill: link.isConnected ? Neo.green : Neo.card))
            .accessibilityLabel("Settings")
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.bold))
                TextField("Search", text: $searchText)
                    .focused($searchFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .onSubmit {
                        searchFocused = false
                    }
                if searchFocused || !searchText.isEmpty {
                    Button {
                        if !searchText.isEmpty {
                            searchText = ""
                        }
                        searchFocused = false
                    } label: {
                        Image(systemName: searchText.isEmpty ? "keyboard.chevron.compact.down" : "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(searchText.isEmpty ? "Dismiss Keyboard" : "Clear Search")
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Neo.ink)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .neoCard(Neo.card)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        if value.translation.height > 20, abs(value.translation.height) > abs(value.translation.width) {
                            searchFocused = false
                        }
                    }
            )
            Button {
                compose()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(NeoIconButtonStyle(fill: Neo.red, size: 48))
            .accessibilityLabel("New Note")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Neo.paper.opacity(0.95).ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: searchText.isEmpty ? "waveform" : "magnifyingglass")
                .font(.largeTitle.weight(.black))
            Text(searchText.isEmpty ? "No notes yet" : "No results")
                .font(.headline.weight(.heavy))
            Text(searchText.isEmpty ? "Record on your device or tap the pencil." : "Try a different search.")
                .font(.subheadline)
                .foregroundStyle(Neo.muted)
        }
        .foregroundStyle(Neo.ink)
        .frame(maxWidth: .infinity)
        .padding(24)
        .neoCard(Neo.yellow)
    }

    private var subtitle: String {
        if link.isRecording {
            return "Recording…"
        }
        let count = notes.count
        return count == 1 ? "1 note" : "\(count) notes"
    }

    private func compose() {
        let note = Note()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            context.insert(note)
            try? context.save()
        }
        openNote(note)
    }

    private func openNote(_ note: Note) {
        searchFocused = false
        var next = NavigationPath()
        next.append(note)
        path = next
    }

    private func openYear(_ dayKey: String) {
        searchFocused = false
        var next = NavigationPath()
        next.append(YearDestination(dayKey: dayKey))
        path = next
    }

    private func delete(_ items: [Note]) {
        for note in items {
            AudioStore.remove(note.audioFileName)
            context.delete(note)
        }
        try? context.save()
    }
}
