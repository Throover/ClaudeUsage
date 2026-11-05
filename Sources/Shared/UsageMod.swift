// Installs the terminal line (the mod shipped in the app) through Claude Code's own plugin commands.
import Foundation

enum UsageMod {
    static let pluginID = "usage@claude-usage-local"
    static let marketplaceName = "claude-usage-local"

    /// A stable copy: the marketplace must survive the app being moved or updated.
    static var installedMarketplace: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClaudeUsage/marketplace")
    }

    static var bundledMarketplace: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("marketplace")
    }

    static func isInstalled() -> Bool {
        guard let result = ClaudeCLI.run(["plugin", "list", "--json"]), result.status == 0,
              let list = try? JSONSerialization.jsonObject(with: result.output) as? [[String: Any]]
        else { return false }
        return list.contains { $0["id"] as? String == pluginID && $0["enabled"] as? Bool != false }
    }

    /// Keeps the installed copy in step with this version of the app.
    static func syncFiles(from source: URL? = bundledMarketplace) {
        guard let source, FileManager.default.fileExists(atPath: source.path) else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: installedMarketplace.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? fm.removeItem(at: installedMarketplace)
        try? fm.copyItem(at: source, to: installedMarketplace)
        localizeLabels()
    }

    /// The mod cannot read the Mac's language, so the app writes the labels into its copy.
    private static func localizeLabels() {
        let file = installedMarketplace.appendingPathComponent("mod/usage/hooks/register.ts")
        guard var code = try? String(contentsOf: file, encoding: .utf8) else { return }
        code = code.replacingOccurrences(of: "const SESSION = 'Session'", with: "const SESSION = '\(L.t("mod.session"))'")
        code = code.replacingOccurrences(of: "const WEEK = 'Week'", with: "const WEEK = '\(L.t("mod.week"))'")
        try? code.write(to: file, atomically: true, encoding: .utf8)
    }

    @discardableResult
    static func install(from source: URL? = bundledMarketplace) -> Bool {
        syncFiles(from: source)
        _ = ClaudeCLI.run(["plugin", "marketplace", "add", installedMarketplace.path])
        _ = ClaudeCLI.run(["plugin", "install", pluginID, "--scope", "user"])
        return isInstalled()
    }

    @discardableResult
    static func uninstall() -> Bool {
        _ = ClaudeCLI.run(["plugin", "uninstall", pluginID, "--scope", "user"])
        _ = ClaudeCLI.run(["plugin", "marketplace", "remove", marketplaceName])
        return !isInstalled()
    }
}
