import AppKit
import SwiftUI

/// Where resting the pointer brings the line down: a strip along the top of
/// each screen, as wide and as tall as the user likes, anywhere from left to
/// right. Out of the box it is the whole menu bar. A narrow or thin strip
/// keeps the line up while reaching for menus, status icons or tabs.
/// Width and position are fractions of the screen, so the same strip fits
/// every display.
@MainActor
enum HotZone {
    static let widthRange: ClosedRange<Double> = 0.05...1
    static let heightRange: ClosedRange<Double> = 1...80
    static let delayRange: ClosedRange<Double> = 0.1...1.5

    /// How much of the screen's width it covers.
    static var width: Double {
        get { (UserDefaults.standard.object(forKey: "hotZoneWidth") as? Double ?? 1).clamped(to: widthRange) }
        set { UserDefaults.standard.set(newValue.clamped(to: widthRange), forKey: "hotZoneWidth") }
    }

    /// Where its middle sits, from the left edge (0) to the right edge (1).
    static var center: Double {
        get { (UserDefaults.standard.object(forKey: "hotZoneCenter") as? Double ?? 0.5).clamped(to: 0...1) }
        set { UserDefaults.standard.set(newValue.clamped(to: 0...1), forKey: "hotZoneCenter") }
    }

    /// Its height in points from the top edge, or nil to match the menu bar
    /// of each screen, notch included.
    static var height: Double? {
        get { (UserDefaults.standard.object(forKey: "hotZoneHeight") as? Double)?.clamped(to: heightRange) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.clamped(to: heightRange), forKey: "hotZoneHeight")
            } else {
                UserDefaults.standard.removeObject(forKey: "hotZoneHeight")
            }
        }
    }

    /// How long the pointer rests there before the line comes down. Short
    /// enough to feel instant, long enough that a quick trip does not count.
    static var delay: TimeInterval {
        get { (UserDefaults.standard.object(forKey: "hotZoneDelay") as? Double ?? 0.25).clamped(to: delayRange) }
        set { UserDefaults.standard.set(newValue.clamped(to: delayRange), forKey: "hotZoneDelay") }
    }

    /// What counts as asking for the line once the pointer is there.
    enum Trigger: String {
        /// Resting in the strip for the delay.
        case rest
        /// Pushing on against the top edge, the way the pointer keeps going
        /// when you mean it, while reaching for a tab or a menu stops short.
        case push
    }

    static var trigger: Trigger {
        get { Trigger(rawValue: UserDefaults.standard.string(forKey: "hotZoneTrigger") ?? "") ?? .rest }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "hotZoneTrigger") }
    }

    static let pushRange: ClosedRange<Double> = 20...300

    /// How far, in points of pointer movement, the push goes past the edge.
    static var pushDistance: Double {
        get { (UserDefaults.standard.object(forKey: "hotZonePush") as? Double ?? 60).clamped(to: pushRange) }
        set { UserDefaults.standard.set(newValue.clamped(to: pushRange), forKey: "hotZonePush") }
    }

    /// A key that must be held as well, like a hot corner with a modifier.
    enum Modifier: String, CaseIterable {
        case none, option, command, control, shift

        var flag: CGEventFlags? {
            switch self {
            case .none: nil
            case .option: .maskAlternate
            case .command: .maskCommand
            case .control: .maskControl
            case .shift: .maskShift
            }
        }

        var title: String {
            switch self {
            case .none: L("None")
            case .option: "⌥ Option"
            case .command: "⌘ Command"
            case .control: "⌃ Control"
            case .shift: "⇧ Shift"
            }
        }
    }

    static var modifier: Modifier {
        get { Modifier(rawValue: UserDefaults.standard.string(forKey: "hotZoneModifier") ?? "") ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "hotZoneModifier") }
    }

    /// Whether the key is held, or none is needed. Read from the system as it
    /// is now, so it works while another app is in front.
    static var modifierHeld: Bool {
        guard let flag = modifier.flag else { return true }
        return CGEventSource.flagsState(.combinedSessionState).contains(flag)
    }

    private static let keys = ["hotZoneWidth", "hotZoneCenter", "hotZoneHeight", "hotZoneDelay",
                               "hotZoneTrigger", "hotZonePush", "hotZoneModifier"]

    static func reset() {
        keys.forEach(UserDefaults.standard.removeObject(forKey:))
    }

    /// Whether the pointer is up against the top edge of a screen, within
    /// the strip's width. Where another display sits above there is no edge.
    static func isAtTopEdge(_ point: NSPoint, of screen: NSScreen) -> Bool {
        let strip = rect(on: screen)
        return point.y >= screen.frame.maxY - 0.5 && point.x >= strip.minX && point.x < strip.maxX
    }

    /// What the settings window highlights: the strip, or only the edge it
    /// sits on when pushing is what counts.
    static func previewRect(on screen: NSScreen) -> NSRect {
        var strip = rect(on: screen)
        if trigger == .push {
            strip.origin.y = screen.frame.maxY - 4
            strip.size.height = 4
        }
        return strip
    }

    /// The strip on a screen, kept inside it however far to a side it sits.
    static func rect(on screen: NSScreen) -> NSRect {
        let frame = screen.frame
        let h = height.map { CGFloat($0) } ?? AppDelegate.menuBarBand(of: screen).height
        let w = frame.width * CGFloat(width)
        let x = min(max(frame.minX + frame.width * CGFloat(center) - w / 2, frame.minX), frame.maxX - w)
        return NSRect(x: x, y: frame.maxY - h, width: w, height: h)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}

/// "Hover Area…" in the menu bar: sliders for the strip, shown live on every
/// screen while the window is open.
@MainActor
final class HotZoneSettings: NSObject, NSWindowDelegate {
    static let shared = HotZoneSettings()

    private var window: NSWindow?
    private var previews: [NSWindow] = []

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingView(rootView: HotZoneForm { [weak self] in self?.updatePreviews() })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("Hover Area")
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(host.fittingSize)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        updatePreviews()
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        window = nil
        previews.forEach { $0.orderOut(nil) }
        previews = []
    }

    /// A tinted strip over each screen's own, above the menu bar so it shows
    /// where the pointer has to rest. Clicks pass through it.
    private func updatePreviews() {
        let screens = NSScreen.screens
        while previews.count < screens.count {
            let preview = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            preview.isOpaque = false
            preview.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.35)
            preview.hasShadow = false
            preview.ignoresMouseEvents = true
            preview.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            preview.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            preview.isReleasedWhenClosed = false
            previews.append(preview)
        }
        while previews.count > screens.count { previews.removeLast().orderOut(nil) }
        for (preview, screen) in zip(previews, screens) {
            preview.setFrame(HotZone.previewRect(on: screen), display: true)
            preview.orderFrontRegardless()
        }
    }
}

private struct HotZoneForm: View {
    let onChange: () -> Void

    @State private var trigger = HotZone.trigger
    @State private var width = HotZone.width
    @State private var center = HotZone.center
    @State private var matchesMenuBar = HotZone.height == nil
    @State private var height = HotZone.height ?? 24
    @State private var delay = HotZone.delay
    @State private var push = HotZone.pushDistance
    @State private var modifier = HotZone.modifier

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("The highlighted area at the top of the screen is where the pointer brings the line down."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            row(L("Bring it down by"), value: nil) {
                Picker("", selection: $trigger) {
                    Text(L("Resting there")).tag(HotZone.Trigger.rest)
                    Text(L("Pushing against the top edge")).tag(HotZone.Trigger.push)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            row(L("Width"), value: String(format: "%d%%", Int((width * 100).rounded()))) {
                Slider(value: $width, in: HotZone.widthRange)
            }
            row(L("Position"), value: nil) {
                HStack {
                    Text(L("Left")).font(.caption).foregroundStyle(.secondary)
                    Slider(value: $center, in: 0...1)
                    Text(L("Right")).font(.caption).foregroundStyle(.secondary)
                }
                .disabled(width >= 0.999)
            }
            row(L("Height"), value: matchesMenuBar ? nil : String(format: L("%d pt"), Int(height.rounded()))) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("Same as the menu bar"), isOn: $matchesMenuBar)
                    Slider(value: $height, in: HotZone.heightRange).disabled(matchesMenuBar)
                }
            }
            .disabled(trigger == .push)
            row(L("Wait before bringing it down"), value: String(format: L("%.2f s"), delay)) {
                Slider(value: $delay, in: HotZone.delayRange)
            }
            .disabled(trigger == .push)
            row(L("How far to push"), value: String(format: L("%d pt"), Int(push.rounded()))) {
                Slider(value: $push, in: HotZone.pushRange)
            }
            .disabled(trigger == .rest)
            row(L("Key to hold as well"), value: nil) {
                Picker("", selection: $modifier) {
                    ForEach(HotZone.Modifier.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

            HStack {
                Spacer()
                Button(L("Restore Defaults")) {
                    HotZone.reset()
                    trigger = HotZone.trigger
                    width = HotZone.width
                    center = HotZone.center
                    matchesMenuBar = true
                    height = 24
                    delay = HotZone.delay
                    push = HotZone.pushDistance
                    modifier = HotZone.modifier
                    onChange()
                }
            }
        }
        .padding(22)
        .frame(width: 440)
        .onChange(of: trigger) { _, new in HotZone.trigger = new; onChange() }
        .onChange(of: width) { _, new in HotZone.width = new; onChange() }
        .onChange(of: center) { _, new in HotZone.center = new; onChange() }
        .onChange(of: matchesMenuBar) { _, new in HotZone.height = new ? nil : height; onChange() }
        .onChange(of: height) { _, new in if !matchesMenuBar { HotZone.height = new; onChange() } }
        .onChange(of: delay) { _, new in HotZone.delay = new }
        .onChange(of: push) { _, new in HotZone.pushDistance = new }
        .onChange(of: modifier) { _, new in HotZone.modifier = new }
    }

    private func row<Content: View>(_ title: String, value: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let value { Text(value).monospacedDigit().foregroundStyle(.secondary) }
            }
            content()
        }
    }
}
