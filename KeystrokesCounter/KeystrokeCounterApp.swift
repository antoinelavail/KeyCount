import SwiftUI
import ApplicationServices
import Charts
import ServiceManagement

@main
struct KeystrokeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {}
        .commands {}
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    var activity: NSObjectProtocol?
    var statsWindow: NSWindow?
    private var eventMonitor: Any?
    static private(set) var instance: AppDelegate!
    lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    // keys for UserDefaults data
    
    var clearKeystrokesDaily: Bool {
        get {
            UserDefaults.standard.bool(forKey: "clearKeystrokesDaily")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "clearKeystrokesDaily")
        }
    }

    @Published var keystrokeCount: Int {
        didSet {
            UserDefaults.standard.set(keystrokeCount, forKey: "keystrokesToday")
        }
    }

    @Published var totalKeystrokes: Int {
        didSet {
            UserDefaults.standard.set(totalKeystrokes, forKey: "totalKeystrokes")
        }
    }

    private var eventTap: CFMachPort?
    var menu: ApplicationMenu!

    override init() {
        self.keystrokeCount = UserDefaults.standard.integer(forKey: "keystrokesToday")
        self.totalKeystrokes = UserDefaults.standard.integer(forKey: "totalKeystrokes")
        super.init()
        AppDelegate.instance = self
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Disable App Nap
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Application counts user input data in the background")
        
        // Create a status item and set its properties
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let fontSize: CGFloat = 14.0
            let font = NSFont.systemFont(ofSize: fontSize)
            button.font = font
            updateKeystrokesCount()

            if let font = button.font {
                let offset = -(font.capHeight - font.xHeight) / 2 + 1.0
                button.attributedTitle = NSAttributedString(
                    string: "\(keystrokeCount) ⌨️",
                    attributes: [NSAttributedString.Key.baselineOffset: offset]
                )
            }
            
            // Add direct action for left mouse down
            button.target = self
            button.action = #selector(statusItemClicked)
        }

        // Initialize ApplicationMenu only once
        menu = ApplicationMenu(appDelegate: self)

        // Don't set the menu to allow direct click handling
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.target = self

        // Request accessibility permissions
        requestAccessibilityPermission()

        // Register for key events using event tap
        setupEventTap()
        
        // Setup statsWindow at launch time
        initializeStatsWindow()
        
        // Check if we need to reset daily count
        if clearKeystrokesDaily && KeystrokeHistoryManager.shared.resetDailyCountIfNeeded() {
            keystrokeCount = 0
            updateKeystrokesCount()
        }
    }
    
    // New method to create and initialize the window once
    private func initializeStatsWindow() {
        // Get main screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        
        // Calculate window size and position
        let windowWidth: CGFloat = 420
        let windowHeight: CGFloat = 700
        
        // Create a borderless window positioned offscreen to the RIGHT
        statsWindow = NSWindow(
            contentRect: NSRect(
                x: screenRect.maxX, // Position it offscreen to the right
                y: screenRect.maxY - windowHeight - 20,
                width: windowWidth,
                height: windowHeight
            ),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        statsWindow?.backgroundColor = NSColor.clear
        statsWindow?.alphaValue = 0.0
        statsWindow?.isOpaque = true
        statsWindow?.hasShadow = false
        statsWindow?.level = .statusBar
        statsWindow?.delegate = self
        statsWindow?.titlebarAppearsTransparent = true
        
        // Configure the view with a notification publisher for animation timing
        let animationManager = WindowAnimationManager()
        let hostingController = NSHostingController(
            rootView: KeystrokeChartView(highlightToday: true, todayCount: keystrokeCount)
                .environmentObject(animationManager)
        )
        let hostingView = hostingController.view
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        
        // Make sure the hostingView doesn't overflow the corners
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.masksToBounds = true

        // Add views in the correct order
        statsWindow?.contentView = hostingView
        
        // Make corners rounded
        statsWindow?.contentView?.wantsLayer = true
        statsWindow?.contentView?.layer?.cornerRadius = 12
        statsWindow?.contentView?.layer?.masksToBounds = false
        statsWindow?.contentView?.layer?.shadowOpacity = 0.3
        statsWindow?.contentView?.layer?.shadowRadius = 8
        statsWindow?.contentView?.layer?.shadowOffset = CGSize(width: 0, height: -3)
    }
    
    func updateStatsView() {
        if let window = statsWindow,
           let hostingView = window.contentView?.subviews.first as? NSHostingView<KeystrokeChartView> {
            // Create a new animation manager for the updated view
            let animationManager = WindowAnimationManager()
            
            // Update the view with the new manager
            hostingView.rootView = KeystrokeChartView(highlightToday: true, todayCount: keystrokeCount)
                .environmentObject(animationManager) as! KeystrokeChartView
            
            // Trigger the animations after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .windowTransitionNearing, object: nil)
            }
        }
    }
    
    @objc func showStatsWindow() {
        // Get main screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        
        // Calculate window size and position
        let windowWidth: CGFloat = 420
        let windowHeight: CGFloat = 700
        
        // Update the content view with current data
        updateStatsView()
        
        // Show the window and bring it to the front
        statsWindow?.orderFront(nil)
        statsWindow?.makeKey()
        
        // Combined fade + RIGHT-TO-LEFT slide animation
        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            // Animate both position and opacity
            statsWindow?.animator().setFrame(
                NSRect(
                    x: screenRect.maxX - windowWidth - 20,
                    y: screenRect.maxY - windowHeight - 20,
                    width: windowWidth,
                    height: windowHeight
                ),
                display: true
            )
            statsWindow?.animator().alphaValue = 1.0
            
            // Trigger internal animations at 50% of the transition
            DispatchQueue.main.asyncAfter(deadline: .now() + context.duration * 0.5) {
                // Post a notification to trigger content animations
                NotificationCenter.default.post(name: .windowTransitionNearing, object: nil)
            }
        })
        
        // Set up event monitoring to close the window when focus is lost
        setupEventMonitoring()
    }
    
    func setupEventMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.statsWindow else { return }
            
            // Check if the click was outside the window
            if let clickedWindow = event.window, clickedWindow == window {
                return
            }
            
            // Close the window
            self.closeStatsWindow()
        }
    }
    
    func closeStatsWindow() {
        guard let window = statsWindow, let screen = NSScreen.main else { return }
        
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // Slide-out to the RIGHT and fade-out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            // Animate position (to the right) and opacity
            window.animator().setFrame(
                NSRect(
                    x: screen.visibleFrame.maxX, // Move offscreen to the right
                    y: window.frame.minY,
                    width: window.frame.width,
                    height: window.frame.height
                ),
                display: true
            )
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            self.statsWindow?.orderOut(nil)
        })
    }
    
    private func formatKeystrokeCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 1_000_000 {
            // Divide by 1000.0 to get the thousands value
            let thousands = Double(count) / 1000.0
            // Truncate to one decimal place without rounding
            let truncated = floor(thousands * 10) / 10
            return String(format: "%.1fk", truncated)
                .replacingOccurrences(of: ".0k", with: "k") // Remove decimal if it's .0
        } else {
            // Same for millions
            let millions = Double(count) / 1_000_000.0
            let truncated = floor(millions * 10) / 10
            return String(format: "%.1fM", truncated)
                .replacingOccurrences(of: ".0M", with: "M") // Remove decimal if it's .0
        }
    }
    
    func updateKeystrokesCount() {
        if let button = statusItem.button {
            let formattedCount = formatKeystrokeCount(keystrokeCount)
            let displayString = menu?.showNumbersOnly == true ? formattedCount : "\(formattedCount) ⌨️"
            
            button.title = displayString

            // Calculate the minimum width based on the formatted text
            let minWidth: CGFloat = 60.0

            if let font = button.font {
                let offset = -(font.capHeight - font.xHeight) / 2 + 1.0
                button.attributedTitle = NSAttributedString(
                    string: displayString,
                    attributes: [NSAttributedString.Key.baselineOffset: offset]
                )
            }

            // Set the minimum width
            statusItem.length = minWidth
        }
    }


    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("Please enable accessibility permissions for the app.")
        }
    }

    func handleEvent(_ event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // Check if this is a shortcut (has modifier keys)
        let modifierFlags: UInt64 = [
            CGEventFlags.maskCommand,
            CGEventFlags.maskShift,
            CGEventFlags.maskAlternate,
            CGEventFlags.maskControl
        ].reduce(0) { $0 | ($1.rawValue & flags.rawValue) }
        
        if modifierFlags != 0 {
            // This is a shortcut, record it
            KeyUsageTracker.shared.recordShortcut(keyCode: keyCode, modifiers: modifierFlags)
        } else {
            // This is a regular keystroke
            keystrokeCount += 1
            totalKeystrokes += 1
            updateKeystrokesCount()

            // Record the key press
            KeyUsageTracker.shared.recordKeyPress(keyCode: keyCode)
        }

        // Check if it's a new day
        if clearKeystrokesDaily && KeystrokeHistoryManager.shared.resetDailyCountIfNeeded() {
            // Save yesterday's count
            KeystrokeHistoryManager.shared.saveDailyCount(keystrokeCount)
            
            // Reset daily keystrokes count
            keystrokeCount = 1  // Set to 1 because we just counted a keystroke
        }
    }
    
    
    func setupEventTap() {
        // Create mask for key down events only
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,  // Use only the key down event mask
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return nil
                }
                
                // Only process if it's actually a keyDown event
                if type == .keyDown {
                    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                    appDelegate.handleEvent(event)
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: selfPointer
        )

        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            CFRunLoopRun()
        }
    }

    @objc func statusItemClicked() {
        // If statistics window exists and is visible, close it
        if let window = statsWindow, window.isVisible {
            closeStatsWindow()
        } else {
            // Otherwise, show it
            showStatsWindow()
        }
    }
    
    @objc func terminateApp() {
        UserDefaults.standard.synchronize()
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        NSApplication.shared.terminate(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        KeyUsageTracker.shared.saveData()
    }
}

class ApplicationMenu: ObservableObject {
    var appDelegate: AppDelegate
    var menu: NSMenu!
    var settingsWindow: NSWindow?
    @Published var showNumbersOnly: Bool = false {
        didSet {
            UserDefaults.standard.set(showNumbersOnly, forKey: "ShowNumbersOnly")
            appDelegate.updateKeystrokesCount()
        }
    }
    @Published var launchAtLogin: Bool = false {
        didSet {
            toggleLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        self.showNumbersOnly = UserDefaults.standard.bool(forKey: "ShowNumbersOnly")
        
        // Check current login item status
        self.launchAtLogin = isLaunchAtLoginEnabled()
    }
    
    // Login item management methods
    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            // For macOS 13+ we can use SMAppService
            let service = SMAppService.mainApp
            return service.status == .enabled
        } else {
            // For earlier versions we check using bundle identifier
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
            if let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]] {
                return jobs.contains { job in
                    return (job["Label"] as? String) == bundleIdentifier
                }
            }
            return false
        }
    }
    
    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            // For macOS 13+ we can use SMAppService
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status == .notRegistered {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // For earlier versions we use SMLoginItemSetEnabled
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
            SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled)
        }
    }
    
    @objc func toggleLaunchAtLoginSetting() {
        launchAtLogin.toggle()
        // Update menu item state
        if let item = menu.item(withTitle: "Launch at Login") {
            item.state = launchAtLogin ? .on : .off
        }
    }
}
