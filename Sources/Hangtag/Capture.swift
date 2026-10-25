import AppKit

/// The screenshot shortcut from the menu bar. It starts the macOS screenshot
/// tool to select an area, or a window after pressing Space, and saves where
/// screenshots go, tagged as a screenshot, so it hangs like any other. Escape
/// cancels. macOS asks once for Screen Recording permission.
@MainActor
enum Capture {
    private static var running: Process?

    /// Formats the line can show, as set with `defaults write com.apple.screencapture type`.
    private static let imageTypes: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif"]

    static func selection() {
        // A second press while selecting is ignored, as macOS does.
        guard running == nil else { return }
        let folder = Inbox.isEnabled ? Inbox.folder : ScreenshotWatcher.screenshotFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let preferred = (CFPreferencesCopyAppValue("type" as CFString, "com.apple.screencapture" as CFString) as? String)?
            .lowercased()
        let type = preferred.flatMap { imageTypes.contains($0) ? $0 : nil } ?? "png"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-t", type, uniqueURL(in: folder, type: type).path]
        process.terminationHandler = { _ in
            DispatchQueue.main.async { running = nil }
        }
        do {
            try process.run()
            running = process
        } catch {
            log.error("Could not start the screenshot tool: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    /// "Screenshot 2026-10-26 01.51.13.png", in the menus' language, and
    /// "… 2" when two land in the same second.
    private static func uniqueURL(in folder: URL, type: String) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let base = String(format: L("Screenshot %@"), formatter.string(from: Date()))
        var url = folder.appendingPathComponent(base).appendingPathExtension(type)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(type)
            n += 1
        }
        return url
    }
}
