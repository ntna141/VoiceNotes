import Foundation

struct NoteSection: Identifiable {
    let id: String
    let title: String
    let notes: [Note]
}

enum NoteSections {
    static func group(_ notes: [Note], now: Date = Date(), calendar: Calendar = .current) -> [NoteSection] {
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday)!
        let thisYear = calendar.component(.year, from: now)

        var order: [String] = []
        var buckets: [String: (String, [Note])] = [:]
        for note in notes {
            let date = note.createdAt
            let key: String
            let title: String
            if date >= startOfToday {
                key = "today"; title = "Today"
            } else if date >= yesterday {
                key = "yesterday"; title = "Yesterday"
            } else if date >= weekAgo {
                key = "week"; title = "Previous 7 Days"
            } else if date >= monthAgo {
                key = "month"; title = "Previous 30 Days"
            } else {
                let year = calendar.component(.year, from: date)
                if year == thisYear {
                    let month = calendar.component(.month, from: date)
                    key = "m\(month)"
                    title = calendar.monthSymbols[month - 1]
                } else {
                    key = "y\(year)"
                    title = String(year)
                }
            }
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = (title, [])
            }
            buckets[key]?.1.append(note)
        }
        return order.map { NoteSection(id: $0, title: buckets[$0]!.0, notes: buckets[$0]!.1) }
    }

    static func rowDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        if date >= startOfToday {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if date >= calendar.date(byAdding: .day, value: -1, to: startOfToday)! {
            return "Yesterday"
        }
        if date >= calendar.date(byAdding: .day, value: -7, to: startOfToday)! {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.defaultDigits).day().year(.twoDigits))
    }
}
