import Foundation

/// Reads the common subset of OpenStreetMap's `opening_hours` format, e.g. "24/7",
/// "Mo-Fr 07:00-23:00; Sa,Su 08:00-22:00" or "Fr,Sa 18:00-03:00". Anything it can't read in full
/// (holidays, week numbers, "sunset"…) makes `init` fail, so a place is never wrongly shown as open.
nonisolated struct OpeningHours: Sendable {
    let raw: String
    let isAlwaysOpen: Bool
    /// Open spans per weekday (0 = Monday) in minutes since midnight; an end past 1440 runs into the next day
    private let week: [[Range<Int>]]

    private static let dayNames = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    /// A comma after a time (or "off") that starts a new day rule, unlike the one in "Sa,Su"
    private static let ruleSeparator = try! Regex(#"(\d|off),\s*(?=(Mo|Tu|We|Th|Fr|Sa|Su|PH)\b)"#)

    init?(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        self.raw = text
        if ["24/7", "00:00-24:00", "Mo-Su 00:00-24:00"].contains(text) {
            isAlwaysOpen = true
            week = Array(repeating: [0..<1440], count: 7)
            return
        }

        // "Mo-Fr 08:00-20:00, Sa 10:00-18:00" is a common way of writing two rules
        let rules = text
            .replacing(Self.ruleSeparator) { "\($0.output[1].substring ?? "");" }
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var week: [[Range<Int>]] = Array(repeating: [], count: 7)
        for rule in rules {
            let firstToken = rule.prefix { !$0.isWhitespace }
            let startsWithDays = firstToken.first?.isLetter == true && !["off", "closed"].contains(firstToken.lowercased())
            let daysPart = startsWithDays ? String(firstToken) : nil
            let timesPart = startsWithDays ? rule.dropFirst(firstToken.count).trimmingCharacters(in: .whitespaces) : rule

            guard let days = daysPart.map(Self.days(in:)) ?? Set(0..<7) else { return nil }
            // A rule only about public holidays doesn't change normal days
            if days.isEmpty { continue }

            if ["off", "closed"].contains(timesPart.lowercased()) {
                for day in days { week[day] = [] }
                continue
            }
            guard let spans = Self.spans(in: timesPart) else { return nil }
            // Later rules replace earlier ones for the days they name
            for day in days { week[day] = spans }
        }
        guard week.contains(where: { !$0.isEmpty }) else { return nil }
        isAlwaysOpen = week.allSatisfy { $0.contains { $0.lowerBound == 0 && $0.upperBound >= 1440 } }
        self.week = week
    }

    func isOpen(at date: Date = .now) -> Bool {
        if isAlwaysOpen { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday, let hour = components.hour, let minute = components.minute else { return false }
        let today = (weekday + 5) % 7
        let yesterday = (today + 6) % 7
        let now = hour * 60 + minute
        return week[today].contains { $0.contains(now) }
            || week[yesterday].contains { $0.contains(now + 1440) }
    }

    /// "Mo-Fr", "Sa,Su", "Fr-Mo", "PH" (ignored). nil when a token isn't understood.
    private static func days(in text: String) -> Set<Int>? {
        var result = Set<Int>()
        for token in text.split(separator: ",") {
            if token == "PH" || token == "SH" { continue }
            let bounds = token.split(separator: "-").map(String.init)
            guard (1...2).contains(bounds.count),
                  let start = dayNames.firstIndex(of: bounds[0]),
                  let end = dayNames.firstIndex(of: bounds.last!) else {
                return nil
            }
            var day = start
            result.insert(day)
            while day != end {
                day = (day + 1) % 7
                result.insert(day)
            }
        }
        return result
    }

    /// "07:00-23:00,23:30-24:00" or "18:00-03:00". nil when a part isn't understood.
    private static func spans(in text: String) -> [Range<Int>]? {
        var result: [Range<Int>] = []
        for part in text.split(separator: ",") {
            let bounds = part.trimmingCharacters(in: .whitespaces).split(separator: "-")
            guard bounds.count == 2, let start = minutes(bounds[0]), var end = minutes(bounds[1]) else { return nil }
            if end <= start { end += 1440 }
            result.append(start..<end)
        }
        return result.isEmpty ? nil : result
    }

    private static func minutes(_ text: Substring) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]),
              (0...24).contains(hours), (0..<60).contains(minutes) else {
            return nil
        }
        return hours * 60 + minutes
    }
}
