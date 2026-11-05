// Menu bar app: displays ~/.claude/claude-usage.json. Never touches the keychain.
import AppKit
import ServiceManagement
import SwiftUI

// MARK: - Model

struct Window: Equatable {
    var percent: Double
    var resetsAt: Date
    /// A window whose reset date has passed is back to zero, even with no new data.
    var effectivePercent: Double { resetsAt <= Date() ? 0 : percent }
    var hasReset: Bool { resetsAt <= Date() }
}

func usageColor(_ percent: Double) -> NSColor {
    // Display thresholds: not sourced, see CONTEXT.md.
    if percent >= 80 { return .systemRed }
    if percent >= 50 { return .systemYellow }
    return .systemGreen
}

@MainActor
final class Store: ObservableObject {
    @Published var session: Window?
    @Published var weekly: Window?
    @Published var updatedAt: Date?
    @Published var status = "…"
    @Published var statusOK: Bool?
    @Published var installed: String?
    @Published var latest: String?
    @Published var now = Date()
    @Published var refreshing = false
    @Published var refreshFailed = false
    @Published var modInstalled = false
    @Published var modBusy = true
    private var lastPoll = Date.distantPast
    @Published var showSession = UserDefaults.standard.object(forKey: "showSession") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showSession, forKey: "showSession") }
    }
    @Published var showWeekly = UserDefaults.standard.object(forKey: "showWeekly") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showWeekly, forKey: "showWeekly") }
    }
    @Published var dismissedVersion = UserDefaults.standard.string(forKey: "dismissedVersion") ?? "" {
        didSet { UserDefaults.standard.set(dismissedVersion, forKey: "dismissedVersion") }
    }

    private let stateURL = usageStateURL
    private var timers: [Timer] = []

    init() {
        reload()
        schedule(5) { $0.reload() }
        schedule(300) { s in Task { await s.fetchStatus(); await s.poll() } }
        schedule(3600) { s in Task { await s.fetchVersions() } }
        Task { await poll(); await fetchStatus(); await fetchVersions(); await checkMod() }
    }

    func checkMod() async {
        modBusy = true
        modInstalled = await Task.detached { () -> Bool in
            let installed = UsageMod.isInstalled()
            // An updated app brings its updated mod; nothing is added for someone who never opted in.
            if installed, FileManager.default.fileExists(atPath: UsageMod.installedMarketplace.path) {
                UsageMod.syncFiles()
            }
            return installed
        }.value
        modBusy = false
    }

    func setMod(_ enabled: Bool) {
        guard !modBusy else { return }
        modBusy = true
        modInstalled = enabled
        Task {
            let works = await Task.detached {
                enabled ? UsageMod.install() : UsageMod.uninstall()
            }.value
            modInstalled = works ? enabled : !enabled
            modBusy = false
        }
    }

    /// Reads the live usage through the Claude Code CLI.
    func poll() async {
        guard !refreshing else { return }
        refreshing = true
        lastPoll = Date()
        let usage = await Task.detached { () -> LiveUsage? in
            guard let text = fetchUsageText() else { return nil }
            let usage = parseUsageText(text)
            guard usage.matched else { return nil }
            writeUsage(session: usage.session, weekly: usage.weekly, fresh: true)
            return usage
        }.value
        refreshFailed = usage == nil
        refreshing = false
        reload()
    }

    /// Opening the panel refreshes too, at most once a minute.
    func pollIfStale() {
        guard Date().timeIntervalSince(lastPoll) > 60 else { return }
        Task { await poll() }
    }

    private func schedule(_ seconds: TimeInterval, _ action: @escaping @MainActor (Store) -> Void) {
        let t = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
            guard let store = self else { return }
            Task { @MainActor in action(store) }
        }
        RunLoop.main.add(t, forMode: .common)
        timers.append(t)
    }

    func refresh() {
        Task { await poll(); await fetchStatus(); await fetchVersions() }
    }

    func reload() {
        now = Date()
        guard let data = try? Data(contentsOf: stateURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        session = Self.parse(root["five_hour"])
        weekly = Self.parse(root["seven_day"])
        if let t = (root["updated_at"] as? NSNumber)?.doubleValue {
            updatedAt = Date(timeIntervalSince1970: t)
        }
    }

    private static func parse(_ value: Any?) -> Window? {
        guard let d = value as? [String: Any],
              let p = (d["used_percentage"] as? NSNumber)?.doubleValue,
              let r = (d["resets_at"] as? NSNumber)?.doubleValue else { return nil }
        return Window(percent: p, resetsAt: Date(timeIntervalSince1970: r))
    }

    func fetchStatus() async {
        guard let url = URL(string: "https://status.claude.com/api/v2/status.json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let s = root["status"] as? [String: Any] else {
            status = L.t("status.unknown"); statusOK = nil; return
        }
        let indicator = s["indicator"] as? String ?? ""
        statusOK = indicator == "none"
        status = indicator == "none" ? L.t("status.ok") : (s["description"] as? String ?? indicator)
    }

    func fetchVersions() async {
        installed = await Task.detached { Self.installedVersion() }.value
        guard let url = URL(string: "https://api.github.com/repos/anthropics/claude-code/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = root["tag_name"] as? String else { return }
        latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    nonisolated private static func installedVersion() -> String? {
        guard let result = ClaudeCLI.run(["--version"]) else { return nil }
        return String(data: result.output, encoding: .utf8)?.split(separator: " ").first.map(String.init)
    }

    var updateAvailable: Bool {
        guard let installed, let latest, latest != dismissedVersion else { return false }
        return installed.compare(latest, options: .numeric) == .orderedAscending
    }
}

// MARK: - Menu bar icon

func menuBarImage(session: Window?, weekly: Window?, showSession: Bool, showWeekly: Bool) -> NSImage {
    let font = NSFont.systemFont(ofSize: 11, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let ringSize: CGFloat = 14, height: CGFloat = 18

    var items: [(String, Window?)] = []
    if showSession { items.append(("S", session)) }
    if showWeekly { items.append(("W", weekly)) }
    if items.isEmpty { items.append(("S", session)) }

    let colored = NSImage(size: NSSize(width: CGFloat(items.count) * 32 + 8, height: height), flipped: false) { rect in
        var x: CGFloat = 1
        for (index, (letter, window)) in items.enumerated() {
            if index > 0 {
                let bar = NSString(string: "|")
                var barAttrs = attrs
                barAttrs[.foregroundColor] = NSColor.labelColor
                bar.draw(at: NSPoint(x: x, y: 2), withAttributes: barAttrs)
                x += 8
            }
            var letterAttrs = attrs
            letterAttrs[.foregroundColor] = NSColor.labelColor
            let text = NSString(string: letter)
            text.draw(at: NSPoint(x: x, y: 2), withAttributes: letterAttrs)
            x += text.size(withAttributes: attrs).width + 2

            let ring = NSRect(x: x + 1.5, y: (rect.height - ringSize) / 2 + 1.5,
                              width: ringSize - 3, height: ringSize - 3)
            let track = NSBezierPath(ovalIn: ring)
            track.lineWidth = 3
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            track.stroke()
            if let percent = window?.effectivePercent, percent > 0 {
                let center = NSPoint(x: ring.midX, y: ring.midY)
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: ring.width / 2, startAngle: 90,
                              endAngle: 90 - 360 * min(percent, 100) / 100, clockwise: true)
                arc.lineWidth = 3
                usageColor(percent).setStroke()
                arc.stroke()
            }
            x += ringSize + 2
        }
        return true
    }
    colored.isTemplate = false
    return colored
}

// MARK: - Formatting

func resetText(_ window: Window, session: Bool, now: Date) -> String {
    if window.resetsAt <= now { return L.t("reset.done") }
    let seconds = window.resetsAt.timeIntervalSince(now)
    if session || seconds < 86_400 {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        if minutes < 60 { return L.f("reset.minutes", minutes) }
        return L.f("reset.hours", minutes / 60, minutes % 60)
    }
    let f = DateFormatter()
    f.locale = L.locale
    f.setLocalizedDateFormatFromTemplate("EEEjmm")
    return L.f("reset.at", f.string(from: window.resetsAt))
}

func agoText(_ date: Date?, now: Date) -> String {
    guard let date else { return L.t("updated.waiting") }
    let minutes = Int(now.timeIntervalSince(date) / 60)
    if minutes < 1 { return L.t("updated.now") }
    if minutes < 60 { return L.f("updated.minutes", minutes) }
    if minutes < 1440 { return L.f("updated.hours", minutes / 60) }
    return L.f("updated.days", minutes / 1440)
}

// MARK: - Views

struct UsageCard: View {
    let title: String
    let window: Window?
    let isSession: Bool
    let now: Date

    var body: some View {
        let percent = window?.effectivePercent
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold))
            HStack(spacing: 18) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.12))
                        if let percent {
                            Capsule().fill(Color(nsColor: usageColor(percent)))
                                .frame(width: geo.size.width * min(percent, 100) / 100)
                        }
                    }
                }
                .frame(height: 8)
                Text(percent.map { "\(Int($0.rounded()))%" } ?? "–")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(width: 38, alignment: .trailing)
            }
            Text(window.map { resetText($0, session: isSession, now: now) } ?? L.t("nodata"))
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

let donationURL = URL(string: "https://ko-fi.com/throover")!

struct SettingsPane: View {
    @ObservedObject var store: Store
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L.t("settings.session"), isOn: $store.showSession)
            Toggle(L.t("settings.weekly"), isOn: $store.showWeekly)
            Toggle(L.t("settings.mod"), isOn: Binding(
                get: { store.modInstalled },
                set: { store.setMod($0) }
            ))
            .disabled(store.modBusy)
            .help(L.t("settings.mod.help"))
            Toggle(L.t("settings.login"), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Button(L.t("donate")) { NSWorkspace.shared.open(donationURL) }
                .buttonStyle(.plain).foregroundStyle(.blue)
        }
        .font(.system(size: 12))
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

struct Panel: View {
    @ObservedObject var store: Store
    @State var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill").font(.system(size: 15))
                Text("Claude Usage").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button { showSettings.toggle() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).help(L.t("settings"))
                if store.refreshing {
                    ProgressView().controlSize(.small).frame(width: 16, height: 16)
                } else {
                    Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).help(L.t("refresh"))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()

            VStack(spacing: 10) {
                if showSettings { SettingsPane(store: store) }
                UsageCard(title: L.t("card.session"), window: store.session, isSession: true, now: store.now)
                UsageCard(title: L.t("card.weekly"), window: store.weekly, isSession: false, now: store.now)
            }
            .padding(12)

            if store.updateAvailable, let installed = store.installed, let latest = store.latest {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill").foregroundStyle(.blue)
                    Button(L.f("update", installed, latest)) {
                        NSWorkspace.shared.open(URL(string: "https://github.com/anthropics/claude-code/releases/tag/v\(latest)")!)
                    }
                    .buttonStyle(.plain).foregroundStyle(.blue)
                    .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Button { store.dismissedVersion = latest } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color.blue.opacity(0.1))
            }

            Divider()
            HStack {
                Text(ClaudeCLI.executable == nil ? L.t("cli.missing")
                     : store.refreshFailed ? L.t("refresh.failed") : agoText(store.updatedAt, now: store.now))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(store.refreshFailed ? Color.orange : Color.secondary)
                Spacer()
                Circle().fill(store.statusOK == true ? .green : (store.statusOK == false ? .orange : .gray))
                    .frame(width: 7, height: 7)
                Button(store.status) { NSWorkspace.shared.open(URL(string: "https://status.claude.com")!) }
                    .buttonStyle(.plain).lineLimit(1)
                Spacer()
                Button(L.t("quit")) { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
            }
            .font(.system(size: 12)).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 9)
        }
        .frame(width: 300)
        // The menu bar window stays alive between openings, so `onAppear` alone is not enough.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            store.reload()
            store.pollIfStale()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            showSettings = false
        }
    }
}

@main
struct ClaudeUsageApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            Panel(store: store)
        } label: {
            Image(nsImage: menuBarImage(session: store.session, weekly: store.weekly,
                                        showSession: store.showSession, showWeekly: store.showWeekly))
        }
        .menuBarExtraStyle(.window)
    }
}
