#if DEBUG
import Foundation
import SwiftData

enum SeedData {
    static func populate(_ context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let samples: [(Int, String, TranscriptionState, Bool)] = [
            (0, "Call the landlord about the heater\nHe said Tuesday morning works, bring the lease copy.", .done, true),
            (0, "Groceries\nEggs, oat milk, spinach, the good coffee beans", .none, false),
            (0, "", .transcribing, true),
            (1, "Ideas for the e-paper picker\nFive faces, boxed selection, hold top button to open it.", .done, true),
            (2, "Dentist rescheduled to the 22nd", .done, true),
            (4, "Book club notes\nEveryone liked chapter 7, next meeting at Mai's place.", .done, true),
            (6, "", .failed, true),
            (12, "Weekend hike\nTrailhead parking fills by 8, bring the filter.", .done, true),
            (20, "Q3 review prep\nLead with the retention numbers, keep the roadmap to one slide.", .none, false),
            (45, "Recipe from grandma\nTwo cups rice, a pinch of salt, steam twenty minutes.", .done, true),
            (80, "Old note from summer\nBeach day with everyone, remember the sunscreen next time.", .done, true),
            (400, "Last year\nThe first recording ever made with the device.", .done, true),
        ]
        for (daysAgo, text, state, hasAudio) in samples {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let lines = text.split(separator: "\n", maxSplits: 1).map(String.init)
            let note = Note(createdAt: date, title: lines.first ?? "", body: lines.count > 1 ? lines[1] : "", audioFileName: hasAudio ? "seed.wav" : nil, transcription: state)
            if state == .failed {
                note.errorMessage = "HTTP 401: invalid API key"
            }
            if hasAudio {
                note.durationSeconds = 42
            }
            context.insert(note)
        }
        let moods = [4, 3, 0, 5, 2, 3, 4, 1, 3, 4, 5, 3, 2, 4, 4, 3, 5, 2, 3, 4, 1, 2, 3, 4, 5, 4, 3, 3, 2, 4]
        for (offset, mood) in moods.enumerated() where mood != 0 {
            let date = calendar.date(byAdding: .day, value: -offset, to: now)!
            context.insert(DayMood(dayKey: DayKey.make(date), mood: mood))
        }
        for month in 1...8 {
            for day in stride(from: 2, to: 28, by: 3) {
                let key = DayKey.make(year: calendar.component(.year, from: now), month: month, day: day)
                if DayKey.date(key).map({ $0 < now }) == true {
                    context.insert(DayMood(dayKey: key, mood: (day + month) % 5 + 1))
                }
            }
        }
        try? context.save()
    }
}
#endif
