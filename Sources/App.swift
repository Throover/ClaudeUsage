// Menu bar app: displays ~/.claude/claude-usage.json. Never touches the keychain.
// Same design language as TerminalPinch: a native menu, system controls, a monochrome icon.
import AppKit
import Combine
import ServiceManagement
import SwiftUI

// MARK: - Model

struct LimitWindow: Equatable {
    var percent: Double
    var resetsAt: Date
    /// A window whose reset date has passed is back to zero, even with no new data.
    var effectivePercent: Double { resetsAt <= Date() ? 0 : percent }
}

enum MenuBarStyle: String, CaseIterable {
    case gauges, percent
    var label: String { L.t(self == .gauges ? "style.gauges" : "style.percent") }
}

/// Close to a limit the gauges leave the system accent color. Thresholds: see CONTEXT.md.
func warningColor(_ percent: Double) -> NSColor? {
    if percent >= 95 { return .systemRed }
    if percent >= 80 { return .systemOrange }
    return nil
}

@MainActor
final class Store: ObservableObject {
    @Published var session: LimitWindow?
    @Published var weekly: LimitWindow?
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

    @Published var menuBarStyle = MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: "menuBarStyle") ?? "") ?? .gauges {
        didSet { UserDefaults.standard.set(menuBarStyle.rawValue, forKey: "menuBarStyle") }
    }

    private var timers: [Timer] = []

    init() {
        reload()
        schedule(5) { $0.reload() }
        schedule(300) { s in Task { await s.fetchStatus(); await s.poll() } }
        schedule(3600) { s in Task { await s.fetchVersions() } }
        Task { await poll(); await fetchStatus(); await fetchVersions(); await checkMod() }
    }

    private func schedule(_ seconds: TimeInterval, _ action: @escaping @MainActor (Store) -> Void) {
        let t = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
            guard let store = self else { return }
            Task { @MainActor in action(store) }
        }
        RunLoop.main.add(t, forMode: .common)
        timers.append(t)
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

    /// Opening the menu refreshes too, at most once a minute.
    func pollIfStale() {
        guard Date().timeIntervalSince(lastPoll) > 60 else { return }
        Task { await poll() }
    }

    func refresh() {
        Task { await poll(); await fetchStatus(); await fetchVersions() }
    }

    func reload() {
        now = Date()
        guard let data = try? Data(contentsOf: usageStateURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        session = Self.parse(root["five_hour"])
        weekly = Self.parse(root["seven_day"])
        if let t = (root["updated_at"] as? NSNumber)?.doubleValue {
            updatedAt = Date(timeIntervalSince1970: t)
        }
    }

    private static func parse(_ value: Any?) -> LimitWindow? {
        guard let d = value as? [String: Any],
              let p = (d["used_percentage"] as? NSNumber)?.doubleValue,
              let r = (d["resets_at"] as? NSNumber)?.doubleValue else { return nil }
        return LimitWindow(percent: p, resetsAt: Date(timeIntervalSince1970: r))
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
        guard let installed, let latest else { return false }
        return installed.compare(latest, options: .numeric) == .orderedAscending
    }
}

// MARK: - Menu bar icon

/// "S" and "W", each with a round gauge or a percentage. Monochrome like any system icon,
/// unless a limit is near.
func menuBarImage(session: LimitWindow?, weekly: LimitWindow?, showSession: Bool, showWeekly: Bool,
                  style: MenuBarStyle) -> NSImage {
    var items: [(String, LimitWindow?)] = []
    if showSession { items.append(("S", session)) }
    if showWeekly { items.append(("W", weekly)) }
    if items.isEmpty { items.append(("S", session)) }

    let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    let ring: CGFloat = 13, line: CGFloat = 2.5, gap: CGFloat = 7, height: CGFloat = 18
    let values = items.map { item in
        item.1.map { "\(Int($0.effectivePercent.rounded()))%" } ?? "–"
    }
    let size: (String) -> CGFloat = { ($0 as NSString).size(withAttributes: [.font: font]).width }
    let widths = items.indices.map { index -> CGFloat in
        size(items[index].0) + 3 + (style == .gauges ? ring : size(values[index]))
    }
    let width = widths.reduce(0, +) + CGFloat(items.count - 1) * gap
    let warning = items.contains { warningColor($0.1?.effectivePercent ?? 0) != nil }

    let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
        var x: CGFloat = 0
        for (index, (letter, window)) in items.enumerated() {
            let percent = window?.effectivePercent ?? 0
            let base = warning ? NSColor.labelColor : NSColor.black
            let tint = warningColor(percent) ?? base
            (letter as NSString).draw(at: NSPoint(x: x, y: 2), withAttributes: [.font: font, .foregroundColor: base])
            x += size(letter) + 3

            if style == .percent {
                (values[index] as NSString).draw(at: NSPoint(x: x, y: 2), withAttributes: [.font: font, .foregroundColor: tint])
            } else {
                let radius = (ring - line) / 2
                let center = NSPoint(x: x + ring / 2, y: height / 2)
                let track = NSBezierPath()
                track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
                track.lineWidth = line
                base.withAlphaComponent(0.3).setStroke()
                track.stroke()
                if percent > 0 {
                    let arc = NSBezierPath()
                    arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                                  endAngle: 90 - 360 * min(percent, 100) / 100, clockwise: true)
                    arc.lineWidth = line
                    arc.lineCapStyle = .round
                    tint.setStroke()
                    arc.stroke()
                }
            }
            x = x - size(letter) - 3 + widths[index] + gap
        }
        return true
    }
    image.isTemplate = !warning
    return image
}

// MARK: - Formatting

func resetText(_ window: LimitWindow, session: Bool, now: Date) -> String {
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

struct UsageRow: View {
    let title: String
    let window: LimitWindow?
    let isSession: Bool
    let now: Date

    var body: some View {
        let percent = window?.effectivePercent
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(percent.map { "\(Int($0.rounded())) %" } ?? "–")
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.15))
                    if let percent, percent > 0 {
                        Capsule()
                            .fill(warningColor(percent).map { Color(nsColor: $0) } ?? Color.accentColor)
                            .frame(width: max(4, geo.size.width * min(percent, 100) / 100))
                    }
                }
            }
            .frame(height: 4)
            Text(window.map { resetText($0, session: isSession, now: now) } ?? L.t("nodata"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct UsageMenuContent: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UsageRow(title: L.t("card.session"), window: store.session, isSession: true, now: store.now)
            UsageRow(title: L.t("card.weekly"), window: store.weekly, isSession: false, now: store.now)
            HStack(spacing: 5) {
                Text(ClaudeCLI.executable == nil ? L.t("cli.missing")
                     : store.refreshFailed ? L.t("refresh.failed") : agoText(store.updatedAt, now: store.now))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                Circle().fill(store.statusOK == true ? .green : (store.statusOK == false ? .orange : .gray))
                    .frame(width: 6, height: 6)
                Text(store.status).lineLimit(1)
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(width: 280)
    }
}

struct SettingsView: View {
    @ObservedObject var store: Store
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle(L.t("settings.session"), isOn: $store.showSession)
                Toggle(L.t("settings.weekly"), isOn: $store.showWeekly)
                Picker(L.t("settings.style"), selection: $store.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            Section {
                Toggle(L.t("settings.mod"), isOn: Binding(
                    get: { store.modInstalled },
                    set: { store.setMod($0) }
                ))
                .disabled(store.modBusy)
                Text(L.t("settings.mod.help")).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle(L.t("settings.login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            Section { Link(L.t("donate"), destination: donationURL) }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

let donationURL = URL(string: "https://ko-fi.com/throover")!

// MARK: - Status item

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = Store()
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settingsWindow: NSWindow?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.setAccessibilityLabel("ClaudeUsage")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
        // objectWillChange fires before the new value is stored: read it on the next pass.
        cancellable = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.updateIcon() }
        }
    }

    private func updateIcon() {
        statusItem.button?.image = menuBarImage(session: store.session, weekly: store.weekly,
                                                showSession: store.showSession, showWeekly: store.showWeekly,
                                                style: store.menuBarStyle)
    }

    func menuWillOpen(_ menu: NSMenu) {
        store.reload()
        store.pollIfStale()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let usage = NSMenuItem()
        let host = NSHostingView(rootView: UsageMenuContent(store: store))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        usage.view = host
        menu.addItem(usage)
        menu.addItem(.separator())

        if store.updateAvailable, let installed = store.installed, let latest = store.latest {
            let item = NSMenuItem(title: L.f("update", installed, latest), action: #selector(openUpdate), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        add(menu, L.t("refresh"), #selector(refresh), "r")
        add(menu, L.t("menu.settings"), #selector(showSettings), ",")
        add(menu, L.t("donate"), #selector(donate), "")
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L.t("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func refresh() { store.refresh() }
    @objc private func donate() { NSWorkspace.shared.open(donationURL) }

    @objc private func openUpdate() {
        guard let latest = store.latest,
              let url = URL(string: "https://github.com/anthropics/claude-code/releases/tag/v\(latest)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
            window.title = "ClaudeUsage"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

@main
enum ClaudeUsageApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
