import Foundation
import SwiftData

@Model
final class DayMood {
    #Unique<DayMood>([\.dayKey])
    #Index<DayMood>([\.dayKey], [\.date])

    var dayKey: String = ""
    var date: Date = Date()
    var mood: Int = 0
    var updatedAt: Date = Date()

    init(dayKey: String, mood: Int) {
        self.dayKey = dayKey
        self.date = DayKey.date(dayKey) ?? Date()
        self.mood = mood
        self.updatedAt = Date()
    }
}

extension ModelContext {
    func mood(for dayKey: String) -> Int {
        var descriptor = FetchDescriptor<DayMood>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        return (try? fetch(descriptor))?.first?.mood ?? 0
    }

    func setMood(_ mood: Int, for dayKey: String) {
        var descriptor = FetchDescriptor<DayMood>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        let existing = (try? fetch(descriptor))?.first
        if mood == 0 {
            if let existing {
                delete(existing)
            }
        } else if let existing {
            existing.mood = mood
            existing.updatedAt = Date()
        } else {
            insert(DayMood(dayKey: dayKey, mood: mood))
        }
        try? save()
    }

    func moods(year: Int, month: Int) -> [Int] {
        let prefix = String(format: "%04d-%02d-", year, month)
        let descriptor = FetchDescriptor<DayMood>(predicate: #Predicate { $0.dayKey.starts(with: prefix) })
        var result = [Int](repeating: 0, count: 31)
        for entry in (try? fetch(descriptor)) ?? [] {
            if let day = Int(entry.dayKey.suffix(2)), (1...31).contains(day) {
                result[day - 1] = entry.mood
            }
        }
        return result
    }

    func moods(year: Int) -> [String: Int] {
        let prefix = String(format: "%04d-", year)
        let descriptor = FetchDescriptor<DayMood>(predicate: #Predicate { $0.dayKey.starts(with: prefix) })
        var result: [String: Int] = [:]
        for entry in (try? fetch(descriptor)) ?? [] {
            result[entry.dayKey] = entry.mood
        }
        return result
    }
}
