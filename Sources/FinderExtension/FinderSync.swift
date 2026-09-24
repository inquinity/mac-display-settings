import Cocoa
import FinderSync
import os

/// Finder Sync extension that adds "Display Settings…" to the contextual
/// menu shown when the user Control-clicks the empty desktop background.
///
/// Prototype goal: confirm that Finder asks for a `.contextualMenuForContainer`
/// menu when the desktop background is clicked, and log what it reports.
@objc(FinderSync)
final class FinderSync: FIFinderSync {

    private let logger = Logger(subsystem: "com.altmansoftwaredesign.DisplaySettingsMenu",
                                category: "FinderSync")

    private static let displaySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!

    /// The user's real ~/Desktop. `FileManager.homeDirectoryForCurrentUser`
    /// returns the sandbox container here, so ask the password database.
    private let desktopURL: URL = {
        let homePath = getpwuid(getuid()).flatMap { String(cString: $0.pointee.pw_dir) }
            ?? NSHomeDirectory()
        return URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent("Desktop", isDirectory: true)
            .standardizedFileURL
    }()

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [desktopURL]
        logger.notice("Extension started; watching \(self.desktopURL.path, privacy: .public)")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let targetedURL = FIFinderSyncController.default().targetedURL()?.standardizedFileURL
        logger.notice("""
            menu(for:) kind=\(menuKind.rawValue, privacy: .public) \
            target=\(targetedURL?.path ?? "nil", privacy: .public)
            """)

        // Only the background of the Desktop itself, not items on it and
        // not Finder windows showing subfolders of ~/Desktop.
        guard menuKind == .contextualMenuForContainer, targetedURL == desktopURL else {
            return nil
        }

        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "Display Settings…",
                     action: #selector(openDisplaySettings(_:)),
                     keyEquivalent: "")
        return menu
    }

    @IBAction func openDisplaySettings(_ sender: AnyObject?) {
        logger.notice("Opening Displays settings")
        NSWorkspace.shared.open(Self.displaySettingsURL)
    }
}
