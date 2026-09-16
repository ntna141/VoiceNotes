import Foundation

enum PageEncoder {
    static let maxDays = 31
    static let wireBytes = 17 + maxDays

    static func page(year: Int, month: Int, today: Int, moods: [Int], force: Bool, now: Date = Date(), calendar: Calendar = .current) -> Data {
        let start = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let firstWeekday = calendar.component(.weekday, from: start) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)!.count
        var payload = Data()
        payload.append(contentsOf: [0x70, 0x61, 0x67, 0x00])
        payload.appendLittleEndian(UInt32(now.timeIntervalSince1970))
        payload.appendLittleEndian(Int16(calendar.timeZone.secondsFromGMT(for: now) / 60))
        payload.appendLittleEndian(UInt16(year))
        payload.append(UInt8(month))
        payload.append(UInt8(today))
        payload.append(UInt8(firstWeekday))
        payload.append(UInt8(daysInMonth))
        payload.append(force ? 1 : 0)
        for day in 0..<maxDays {
            let mood = day < moods.count ? moods[day] : 0
            payload.append(UInt8(clamping: max(0, min(mood, MoodIcons.count))))
        }
        return payload
    }

    static func mood(year: Int, month: Int, day: Int, mood: Int) -> Data {
        var payload = Data([0x6D, 0x6F, 0x64, 0x00])
        payload.appendLittleEndian(UInt16(year))
        payload.append(UInt8(month))
        payload.append(UInt8(day))
        payload.append(UInt8(clamping: max(0, min(mood, MoodIcons.count))))
        return payload
    }

    static func time(now: Date = Date(), calendar: Calendar = .current) -> Data {
        var payload = Data()
        payload.append(contentsOf: [0x74, 0x69, 0x6D, 0x00])
        payload.appendLittleEndian(UInt32(now.timeIntervalSince1970))
        payload.appendLittleEndian(Int16(calendar.timeZone.secondsFromGMT(for: now) / 60))
        return payload
    }

    static func icons(_ set: [[UInt8]]) -> Data {
        var payload = Data([0x69, 0x63, 0x6F, 0x00])
        for icon in set {
            payload.append(contentsOf: icon)
        }
        return payload
    }

    static func iconsReset() -> Data {
        Data([0x69, 0x63, 0x6F, 0x00])
    }
}
