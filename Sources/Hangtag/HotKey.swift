import AppKit
import Carbon

/// A global shortcut through the Carbon hot key API. Unlike a global key
/// monitor, it needs no Accessibility permission.
final class HotKey {
    /// What each shortcut does: showing the line, taking a screenshot.
    enum Purpose: UInt32 {
        case line = 1, screenshot = 2
    }

    private var ref: EventHotKeyRef?
    private static var actions: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    /// Nil when the combination cannot be registered, for example because
    /// another app already took it.
    init?(_ shortcut: Shortcut, for purpose: Purpose, action: @escaping () -> Void) {
        HotKey.actions[purpose.rawValue] = action
        // One handler for the app, however many shortcuts and changes.
        if !HotKey.handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var pressed = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
                DispatchQueue.main.async { HotKey.actions[pressed.id]?() }
                return noErr
            }, 1, &spec, nil, nil)
            HotKey.handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x4841_4E47), id: purpose.rawValue) // "HANG"
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode), UInt32(shortcut.carbonModifiers), id,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, ref != nil else { return nil }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
    }
}

/// A global shortcut: the one that shows and hides the line, and the one
/// that takes a screenshot.
struct Shortcut: Equatable {
    var keyCode: Int
    var modifiers: NSEvent.ModifierFlags
    /// The key as typed, for the menu: "t", " ", "1".
    var key: String

    static let standard = Shortcut(keyCode: kVK_ANSI_T, modifiers: [.control, .option], key: "t")

    /// Shows and hides the line: ⌃⌥T unless changed. Nil means none at all.
    static var current: Shortcut? {
        get { load("shortcut", default: standard) }
        set { save(newValue, "shortcut") }
    }

    /// Takes a screenshot. None until the user picks one.
    static var screenshot: Shortcut? {
        get { load("screenshotShortcut", default: nil) }
        set { save(newValue, "screenshotShortcut") }
    }

    /// Back to ⌃⌥T for the line.
    static func resetLine() {
        UserDefaults.standard.removeObject(forKey: "shortcut")
    }

    /// Back to none for screenshots, so the ones of macOS take them.
    static func resetScreenshot() {
        UserDefaults.standard.removeObject(forKey: "screenshotShortcut")
    }

    /// A missing entry is the default; an empty one, no shortcut.
    private static func load(_ defaultsKey: String, default fallback: Shortcut?) -> Shortcut? {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey) else { return fallback }
        guard let code = saved["keyCode"] as? Int, let flags = saved["modifiers"] as? UInt,
              let key = saved["key"] as? String else { return nil }
        return Shortcut(keyCode: code, modifiers: NSEvent.ModifierFlags(rawValue: flags), key: key)
    }

    private static func save(_ shortcut: Shortcut?, _ defaultsKey: String) {
        UserDefaults.standard.set(shortcut.map {
            ["keyCode": $0.keyCode, "modifiers": $0.modifiers.rawValue, "key": $0.key] as [String: Any]
        } ?? [:], forKey: defaultsKey)
    }

    /// Whether macOS takes this combination for its own screenshots, in System
    /// Settings > Keyboard > Keyboard Shortcuts > Screenshots. Both would start
    /// at once, so the screenshot shortcut cannot be one of those.
    var isMacOSScreenshotShortcut: Bool {
        // The screen to a file and to the clipboard, a selection to a file and
        // to the clipboard, and the screenshot toolbar, as macOS ships them.
        let builtIn: [String: (Int, NSEvent.ModifierFlags)] = [
            "28": (kVK_ANSI_3, [.command, .shift]), "29": (kVK_ANSI_3, [.command, .shift, .control]),
            "30": (kVK_ANSI_4, [.command, .shift]), "31": (kVK_ANSI_4, [.command, .shift, .control]),
            "184": (kVK_ANSI_5, [.command, .shift]),
        ]
        // Changed or turned off ones are listed here with their new values.
        let changed = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        let mask: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        return builtIn.contains { id, standard in
            var (code, flags) = standard
            if let entry = changed[id] as? [String: Any] {
                if (entry["enabled"] as? Bool) == false { return false }
                if let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int], parameters.count == 3 {
                    code = parameters[1]
                    flags = NSEvent.ModifierFlags(rawValue: UInt(parameters[2]))
                }
            }
            return code == keyCode && flags.intersection(mask) == modifiers.intersection(mask)
        }
    }

    /// From a key press, if it makes a usable global shortcut: it needs
    /// Command, Control or Option, so typing alone never triggers it.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.intersection([.command, .control, .option]).isEmpty,
              let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty else { return nil }
        self.init(keyCode: Int(event.keyCode), modifiers: flags, key: key)
    }

    init(keyCode: Int, modifiers: NSEvent.ModifierFlags, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    var carbonModifiers: Int {
        var carbon = 0
        if modifiers.contains(.command) { carbon |= cmdKey }
        if modifiers.contains(.control) { carbon |= controlKey }
        if modifiers.contains(.option) { carbon |= optionKey }
        if modifiers.contains(.shift) { carbon |= shiftKey }
        return carbon
    }

    /// As macOS writes it in menus: ⌃⌥⇧⌘ and the key.
    var display: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + (key == " " ? L("Space") : key.uppercased())
    }
}

/// Asks for a new shortcut in a small window: the next key press with
/// Command, Control or Option becomes it. Escape cancels and Delete leaves
/// the line without a shortcut.
@MainActor
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    static let shared = ShortcutRecorder()

    private var window: NSWindow?
    private var monitor: Any?
    private var done: ((Shortcut??) -> Void)?

    /// Calls back with the new shortcut, `.some(nil)` for none, or nil if
    /// cancelled.
    func record(_ done: @escaping (Shortcut??) -> Void) {
        finish(nil)
        self.done = done

        let title = NSTextField(labelWithString: L("Press the new shortcut"))
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        let hint = NSTextField(labelWithString: L("Escape cancels. Delete removes the shortcut."))
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, hint])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 28, bottom: 22, right: 28)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("Change Shortcut")
        window.contentView = stack
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            let plain = event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
            if event.keyCode == UInt16(kVK_Escape) && plain {
                self.finish(nil)
            } else if (event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)) && plain {
                self.finish(.some(nil))
            } else if let shortcut = Shortcut(event: event) {
                self.finish(.some(shortcut))
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        window = nil
        finish(nil)
    }

    private func finish(_ result: Shortcut??) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        let done = self.done
        self.done = nil
        window?.close()
        window = nil
        done?(result)
    }
}
