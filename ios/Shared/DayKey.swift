import Foundation

nonisolated enum DayKey {
    static func make(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func make(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    static var today: String {
        make(Date())
    }

    static func shifted(_ key: String, by days: Int, calendar: Calendar = .current) -> String? {
        guard let base = date(key, calendar: calendar), let target = calendar.date(byAdding: .day, value: days, to: base) else { return nil }
        return make(target, calendar: calendar)
    }

    static func shortLabel(_ key: String) -> String {
        (date(key) ?? Date()).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
