import SwiftData
import SwiftUI

struct YearMoodSheet: View {
    let initialDayKey: String
    let onOpenNote: (Note) -> Void
    let onOpenCanvas: (String) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var moods: [DayMood]
    @State private var year: Int
    @State private var selectedDayKey: String

    private let calendar = Calendar.current

    init(initialDayKey: String, onOpenNote: @escaping (Note) -> Void, onOpenCanvas: @escaping (String) -> Void) {
        self.initialDayKey = initialDayKey
        self.onOpenNote = onOpenNote
        self.onOpenCanvas = onOpenCanvas
        _selectedDayKey = State(initialValue: initialDayKey)
        _year = State(initialValue: Int(initialDayKey.prefix(4)) ?? Calendar.current.component(.year, from: Date()))
    }

    private var moodByDay: [String: Int] {
        Dictionary(uniqueKeysWithValues: moods.map { ($0.dayKey, $0.mood) })
    }

    private var currentYear: Int {
        calendar.component(.year, from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(16)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(1...12, id: \.self) { month in
                            monthGrid(month: month)
                                .id(month)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16 + Neo.shadow)
                    .padding(.bottom, 16)
                }
                .task {
                    try? await Task.sleep(for: .milliseconds(50))
                    if let month = Int(selectedDayKey.dropFirst(5).prefix(2)) {
                        proxy.scrollTo(month, anchor: .top)
                    }
                }
            }
            dayPanel
        }
        .background(Neo.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .tint(Neo.ink)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(NeoIconButtonStyle(size: 40))
            .accessibilityLabel("Back")
            Spacer()
            Button {
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(NeoIconButtonStyle(size: 40))
            Text(String(year))
                .font(.title.weight(.black))
                .foregroundStyle(Neo.ink)
                .frame(minWidth: 80)
            Button {
                year += 1
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(NeoIconButtonStyle(size: 40))
            .disabled(year >= currentYear)
            .opacity(year >= currentYear ? 0.4 : 1)
        }
    }

    private func monthGrid(month: Int) -> some View {
        let start = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let days = calendar.range(of: .day, in: .month, for: start)!.count
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let today = DayKey.today
        let now = Date()
        return VStack(alignment: .leading, spacing: 10) {
            NeoSectionHeader(title: calendar.monthSymbols[month - 1])
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(-leading..<0, id: \.self) { _ in
                    Color.clear.frame(height: 36)
                }
                ForEach(1...days, id: \.self) { day in
                    let key = DayKey.make(year: year, month: month, day: day)
                    let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
                    let future = date > now && key != today
                    Button {
                        selectedDayKey = key
                    } label: {
                        ZStack {
                            if let mood = moodByDay[key], mood != 0 {
                                MoodGlyph(mood: mood, size: 22)
                            } else {
                                Text("\(day)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Neo.muted)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .neoChip(cellFill(key: key, today: today), border: key == selectedDayKey ? 2.5 : Neo.chipBorder)
                        .opacity(future ? 0.3 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(future)
                }
            }
        }
        .padding(12)
        .neoCard()
    }

    private func cellFill(key: String, today: String) -> Color {
        if key == selectedDayKey {
            return Neo.red
        }
        if key == today {
            return Neo.yellow
        }
        return Neo.card
    }

    private var selectedDate: Date {
        DayKey.date(selectedDayKey) ?? Date()
    }

    private var dayPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.headline.weight(.black))
                .foregroundStyle(Neo.ink)
            MoodPickerRow(selected: moodByDay[selectedDayKey] ?? 0, size: 28) { mood in
                context.setMood(mood, for: selectedDayKey)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Button {
                    addEntry()
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Add entry")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NeoButtonStyle(fill: Neo.red))
                .accessibilityLabel("New Note")
                Button {
                    onOpenCanvas(selectedDayKey)
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .buttonStyle(NeoIconButtonStyle(fill: Neo.yellow, size: 42))
                .accessibilityLabel("Photo page")
            }
            .padding(.trailing, Neo.shadow)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Neo.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(Neo.ink).frame(height: Neo.border)
        }
    }

    private func addEntry() {
        let createdAt: Date
        if selectedDayKey == DayKey.today {
            createdAt = Date()
        } else {
            let base = DayKey.date(selectedDayKey) ?? Date()
            let time = calendar.dateComponents([.hour, .minute, .second], from: Date())
            createdAt = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0, of: base) ?? base
        }
        let note = Note(createdAt: createdAt)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            context.insert(note)
            try? context.save()
        }
        onOpenNote(note)
    }
}
