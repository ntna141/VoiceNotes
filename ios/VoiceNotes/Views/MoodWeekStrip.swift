import SwiftUI

struct MoodWeekStrip: View {
    let moodByDay: [String: Int]
    let onSelectDay: (String) -> Void

    @State private var weekOffset = 0

    private static let weeksBack = 104
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    withAnimation { weekOffset = max(weekOffset - 1, -Self.weeksBack) }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(NeoIconButtonStyle(size: 32))
                Button {
                    onSelectDay(visibleDayKey)
                } label: {
                    Text(weekTitle(for: weekOffset).uppercased())
                        .font(.footnote.weight(.black))
                        .foregroundStyle(Neo.ink)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation { weekOffset = min(weekOffset + 1, 0) }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(NeoIconButtonStyle(size: 32))
                .disabled(weekOffset == 0)
                .opacity(weekOffset == 0 ? 0.4 : 1)
            }
            weekRow(offset: weekOffset)
                .frame(height: 84)
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectDay(visibleDayKey)
        }
        .neoCard(Neo.greenSoft)
    }

    private func weekRow(offset: Int) -> some View {
        let days = weekDays(offset: offset)
        let today = DayKey.today
        return HStack(spacing: 6) {
            ForEach(days, id: \.key) { day in
                Button {
                    onSelectDay(day.key)
                } label: {
                    VStack(spacing: 3) {
                        Text(day.weekday)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Neo.muted)
                        Text("\(day.number)")
                            .font(.footnote.weight(.heavy))
                            .foregroundStyle(Neo.ink)
                        MoodGlyph(mood: moodByDay[day.key] ?? 0, size: 24)
                            .opacity(day.isFuture ? 0.25 : 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.key == today ? Neo.yellow : Neo.card)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Neo.ink, lineWidth: 1.5))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(day.isFuture)
            }
        }
    }

    private struct Day {
        let key: String
        let number: Int
        let weekday: String
        let isFuture: Bool
    }

    private var visibleDayKey: String {
        weekOffset == 0 ? DayKey.today : DayKey.make(weekStart(offset: weekOffset))
    }

    private func weekStart(offset: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -delta, to: today)!
        return calendar.date(byAdding: .day, value: offset * 7, to: start)!
    }

    private func weekDays(offset: Int) -> [Day] {
        let start = weekStart(offset: offset)
        let now = Date()
        return (0..<7).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: start)!
            let index = calendar.component(.weekday, from: date) - 1
            return Day(
                key: DayKey.make(date),
                number: calendar.component(.day, from: date),
                weekday: String(calendar.veryShortWeekdaySymbols[index]),
                isFuture: date > now
            )
        }
    }

    private func weekTitle(for offset: Int) -> String {
        if offset == 0 {
            return "This Week"
        }
        if offset == -1 {
            return "Last Week"
        }
        let start = weekStart(offset: offset)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
