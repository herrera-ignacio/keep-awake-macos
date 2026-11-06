import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var interval: TimeInterval = 60
    private let intervals: [TimeInterval] = [5, 30, 60, 120, 300]
    private var schedule: MovementSchedule?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var countdownTimer: Timer?
    private var pauseStatusItem: NSMenuItem?
    private let syntheticEventMarker: Int64 = 0x4B4545504157414B
    private var directionIndex = 0
    private let directions: [(CGFloat, CGFloat)] = [(-60, 0), (60, 0), (0, -60), (0, 60)]
    private var isEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        updateMenu()
    }

    private func updateMenu() {
        statusItem.button?.image = NSImage(systemSymbolName: isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: "Keep Awake")
        statusItem.button?.toolTip = isEnabled ? "Keep Awake is on" : "Keep Awake is off"

        let menu = NSMenu()
        let status = NSMenuItem(title: isEnabled ? "Keep Awake: On" : "Keep Awake: Off", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if isEnabled {
            let pauseStatus = NSMenuItem(title: pauseStatusText, action: nil, keyEquivalent: "")
            pauseStatus.isEnabled = false
            pauseStatusItem = pauseStatus
            menu.addItem(pauseStatus)
        } else {
            pauseStatusItem = nil
        }
        menu.addItem(NSMenuItem.separator())
        let toggle = NSMenuItem(title: isEnabled ? "Turn Off" : "Turn On", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let intervalItem = NSMenuItem(title: "Movement Interval", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for seconds in intervals {
            let item = NSMenuItem(title: seconds < 60 ? "\(Int(seconds)) seconds" : "\(Int(seconds / 60)) \(seconds == 60 ? "minute" : "minutes")", action: #selector(selectInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(seconds)
            item.state = seconds == interval ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Quit Keep Awake", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        if isEnabled {
            stop()
            return
        }
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            let alert = NSAlert()
            alert.messageText = "Accessibility permission is required"
            alert.informativeText = "Allow Keep Awake in System Settings → Privacy & Security → Accessibility, then turn it on again."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        isEnabled = true
        schedule = MovementSchedule(interval: interval, now: ProcessInfo.processInfo.systemUptime)
        guard startMouseMonitoring() else {
            stop()
            let alert = NSAlert()
            alert.messageText = "Unable to monitor mouse movement"
            alert.informativeText = "Check Accessibility permission for Keep Awake, then try turning it on again."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        updateMenu()
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        interval = TimeInterval(sender.tag)
        schedule?.changeInterval(interval, at: ProcessInfo.processInfo.systemUptime)
        updateMenu()
    }

    private var pauseSecondsRemaining: Int {
        schedule?.pauseSecondsRemaining(at: ProcessInfo.processInfo.systemUptime) ?? 0
    }

    private var pauseStatusText: String {
        let seconds = pauseSecondsRemaining
        return seconds > 0 ? "Paused: \(seconds)s" : "Paused: No"
    }

    private func recordUserMovement(_ event: NSEvent) {
        guard isEnabled else { return }
        if let cgEvent = event.cgEvent,
           cgEvent.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker ||
           cgEvent.getIntegerValueField(.eventSourceUnixProcessID) == Int64(ProcessInfo.processInfo.processIdentifier) {
            return
        }
        schedule?.userMoved(at: ProcessInfo.processInfo.systemUptime)
        pauseStatusItem?.title = pauseStatusText
    }

    private func startMouseMonitoring() -> Bool {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.recordUserMovement(event) }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.recordUserMovement(event) }
            return event
        }
        guard globalMouseMonitor != nil, localMouseMonitor != nil else { return false }
        let countdown = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pauseStatusItem?.title = self.pauseStatusText
                if self.schedule?.movementIsDue(at: ProcessInfo.processInfo.systemUptime) == true {
                    self.moveMouse()
                }
            }
        }
        RunLoop.main.add(countdown, forMode: .common)
        RunLoop.main.add(countdown, forMode: .eventTracking)
        countdownTimer = countdown
        return true
    }

    private func moveMouse() {
        guard AXIsProcessTrusted() else {
            stop()
            return
        }
        // Avoid interfering with a click or drag in progress.
        guard pauseSecondsRemaining == 0, NSEvent.pressedMouseButtons == 0,
              let current = CGEvent(source: nil)?.location,
              let display = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }),
              let screenNumber = display.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        // Quartz coordinates have a top-left origin; use the current display's Quartz bounds.
        let bounds = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
        let (dx, dy) = directions[directionIndex]
        directionIndex = (directionIndex + 1) % directions.count
        func clampedPoint(dx: CGFloat, dy: CGFloat) -> CGPoint {
            CGPoint(x: min(max(current.x + dx, bounds.minX), bounds.maxX - 1),
                    y: min(max(current.y + dy, bounds.minY), bounds.maxY - 1))
        }
        var destination = clampedPoint(dx: dx, dy: dy)
        if hypot(destination.x - current.x, destination.y - current.y) < 1 {
            destination = clampedPoint(dx: -dx, dy: -dy)
        }
        guard let outward = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: destination, mouseButton: .left) else { return }
        outward.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        outward.post(tap: .cghidEventTap)

        // Do not pull the pointer away if the user moved it during the pause.
        let returnTimer = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isEnabled, self.pauseSecondsRemaining == 0, AXIsProcessTrusted(), NSEvent.pressedMouseButtons == 0,
                      let position = CGEvent(source: nil)?.location,
                      hypot(position.x - destination.x, position.y - destination.y) < 2,
                      let back = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: current, mouseButton: .left) else { return }
                back.setIntegerValueField(.eventSourceUserData, value: self.syntheticEventMarker)
                back.post(tap: .cghidEventTap)
            }
        }
        RunLoop.main.add(returnTimer, forMode: .common)
        RunLoop.main.add(returnTimer, forMode: .eventTracking)
    }

    private func stop() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        schedule = nil
        isEnabled = false
        updateMenu()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
