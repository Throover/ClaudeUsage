// Live reading through Claude Code's own `/usage` command: no model call, no token,
// and this app never handles a credential.
import Foundation

struct LiveUsage {
    var session: UsageWindow?
    var weekly: UsageWindow?
    var matched: Bool
}

/// Parses lines such as:
/// "Current session: 1% used · resets Nov 5 at 5:10pm (Europe/Rome)"
/// "Current week (all models): 10% used · resets Nov 11 at 6pm (Europe/Rome)"
func parseUsageText(_ text: String, now: Date = Date()) -> LiveUsage {
    func line(_ label: String) -> (pct: Double, reset: Double?)? {
        let pattern = "^\\s*" + NSRegularExpression.escapedPattern(for: label)
            + ":\\s*(\\d+(?:\\.\\d+)?)% used(?:\\s*·\\s*resets (.+?) \\(([^)]+)\\))?\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let pctRange = Range(m.range(at: 1), in: text),
              let pct = Double(text[pctRange]) else { return nil }
        var reset: Double?
        if let d = Range(m.range(at: 2), in: text), let z = Range(m.range(at: 3), in: text) {
            reset = parseResetDate(String(text[d]), zone: String(text[z]), now: now)?.timeIntervalSince1970
        }
        return (pct, reset)
    }
    let s = line("Current session")
    let w = line("Current week (all models)")
    return LiveUsage(
        session: s.flatMap { v in v.reset.map { (v.pct, $0) } },
        weekly: w.flatMap { v in v.reset.map { (v.pct, $0) } },
        matched: s != nil || w != nil)
}

func parseResetDate(_ text: String, zone: String, now: Date) -> Date? {
    guard let tz = TimeZone(identifier: zone) else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = tz
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    f.calendar = calendar
    // Start of day: the default date supplies the year, but must not leak its
    // minutes or seconds into a time written as "6pm".
    f.defaultDate = calendar.startOfDay(for: now)

    for format in ["MMM d 'at' h:mma", "MMM d 'at' ha"] {
        f.dateFormat = format
        if let date = f.date(from: text) {
            // No year in the text: a date well in the past belongs to next year.
            return date < now.addingTimeInterval(-86_400)
                ? calendar.date(byAdding: .year, value: 1, to: date) : date
        }
    }
    for format in ["h:mma", "ha"] {
        f.dateFormat = format
        if let date = f.date(from: text) {
            return date < now ? calendar.date(byAdding: .day, value: 1, to: date) : date
        }
    }
    return nil
}

/// Runs the installed CLI and returns the text of `/usage`, or nil on any failure.
func fetchUsageText() -> String? {
    guard let result = ClaudeCLI.run(["-p", "/usage", "--output-format", "json",
                                      "--no-session-persistence", "--setting-sources", ""]),
          result.status == 0,
          let root = try? JSONSerialization.jsonObject(with: result.output) as? [String: Any],
          root["is_error"] as? Bool == false else { return nil }
    return root["result"] as? String
}
