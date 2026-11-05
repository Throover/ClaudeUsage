// State file rules shared by the status line binary and the app.
import Foundation

typealias UsageWindow = (pct: Double, reset: Double)

let usageStateURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/claude-usage.json")

func readWindow(_ root: [String: Any]?, _ key: String) -> UsageWindow? {
    guard let w = root?[key] as? [String: Any],
          let pct = (w["used_percentage"] as? NSNumber)?.doubleValue,
          let reset = (w["resets_at"] as? NSNumber)?.doubleValue else { return nil }
    return (pct, reset)
}

/// Sources may report data of different ages: an older reset date is ignored and,
/// within one window, usage can only grow.
func mergeWindow(_ old: UsageWindow?, _ new: UsageWindow?) -> (value: UsageWindow?, changed: Bool) {
    guard let new else { return (old, false) }
    guard let old else { return (new, true) }
    if new.reset > old.reset + 60 { return (new, true) }
    if new.reset < old.reset - 60 { return (old, false) }
    return ((max(old.pct, new.pct), max(old.reset, new.reset)), new.pct > old.pct)
}

/// Merges new windows into the state file. `fresh` marks a live reading, which proves the
/// data is current even when the values did not change.
func writeUsage(session: UsageWindow?, weekly: UsageWindow?, fresh: Bool) {
    let previous = (try? Data(contentsOf: usageStateURL))
        .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
    let s = mergeWindow(readWindow(previous, "five_hour"), session)
    let w = mergeWindow(readWindow(previous, "seven_day"), weekly)
    let now = Date().timeIntervalSince1970

    var out: [String: Any] = ["seen_at": now]
    out["updated_at"] = (fresh || s.changed || w.changed)
        ? now : (previous?["updated_at"] as? NSNumber)?.doubleValue ?? now
    if let polled = fresh ? now : (previous?["polled_at"] as? NSNumber)?.doubleValue {
        out["polled_at"] = polled
    }
    if let v = s.value { out["five_hour"] = ["used_percentage": v.pct, "resets_at": v.reset] }
    if let v = w.value { out["seven_day"] = ["used_percentage": v.pct, "resets_at": v.reset] }
    if let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: usageStateURL, options: .atomic)
    }
}
