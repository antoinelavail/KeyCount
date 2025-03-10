import SwiftUI
import ApplicationServices
import Charts

@main
struct KeystrokeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            KeystrokeChartView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Keystroke History") {
                    NSApp.sendAction(#selector(AppDelegate.showHistoryWindow), to: nil, from: nil)
                }
            }
        }
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
    var mainWindow: NSWindow!
    var historyWindow: NSWindow?
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

        // Create the main window but don't show it
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        mainWindow.title = "Keystroke Counter"
        
        // Initialize ApplicationMenu only once
        menu = ApplicationMenu(mainWindow: mainWindow, appDelegate: self)

        // Create the menu
        menu.buildMenu()

        // Don't set the menu to allow direct click handling
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.target = self

        // Request accessibility permissions
        requestAccessibilityPermission()

        // Register for key events using event tap
        setupEventTap()
        
        
        // Check if we need to reset daily count
        if clearKeystrokesDaily && KeystrokeHistoryManager.shared.resetDailyCountIfNeeded() {
            keystrokeCount = 0
            updateKeystrokesCount()
        }
    }
    
    func updateHistoryView() {
        if let window = historyWindow, 
           let hostingView = window.contentView as? NSHostingView<KeystrokeChartView> {
            // Only update the KeystrokeChartView properties, don't add modifiers
            hostingView.rootView = KeystrokeChartView(highlightToday: true, todayCount: keystrokeCount)
        }
    }
    
    @objc func showHistoryWindow() {
        // Get main screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        
        // Calculate window size and position
        let windowWidth: CGFloat = 650
        let windowHeight: CGFloat = 900 // Make it taller to accommodate all sections
        
        // If history window already exists, just show it
        if historyWindow == nil {
            // Create a borderless window
            historyWindow = NSWindow(
                contentRect: NSRect(
                    x: screenRect.maxX, // Start offscreen
                    y: screenRect.maxY - windowHeight,
                    width: windowWidth,
                    height: windowHeight
                ),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            historyWindow?.backgroundColor = NSColor.windowBackgroundColor
            historyWindow?.isOpaque = false
            historyWindow?.hasShadow = true
            historyWindow?.level = .statusBar
            historyWindow?.delegate = self
            
            // Configure the view with today's count highlighted
            let hostingController = NSHostingController(
                rootView: KeystrokeChartView(highlightToday: true, todayCount: keystrokeCount)
            )
            let hostingView = hostingController.view
            hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

            // Add the visual effect as a background
            let visualEffectView = NSVisualEffectView(frame: hostingView.bounds)
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.autoresizingMask = [.width, .height]

            // Add views in the correct order
            historyWindow?.contentView = visualEffectView
            visualEffectView.addSubview(hostingView)
            
            // Make corners rounded
            historyWindow?.contentView?.wantsLayer = true
            historyWindow?.contentView?.layer?.cornerRadius = 10
            historyWindow?.contentView?.layer?.masksToBounds = true
        } else {
            // Update the view with current data
            updateHistoryView()
        }
        
        // Show the window and bring it to the front
        historyWindow?.orderFront(nil)
        historyWindow?.makeKey()
        
        // Animate the window sliding in
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            historyWindow?.animator().setFrame(
                NSRect(
                    x: screenRect.maxX - windowWidth,
                    y: screenRect.maxY - windowHeight,
                    width: windowWidth,
                    height: windowHeight
                ),
                display: true
            )
        })
        
        // Set up event monitoring to close the window when focus is lost
        setupEventMonitoring()
    }
    
    func setupEventMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.historyWindow else { return }
            
            // Check if the click was outside the window
            if let clickedWindow = event.window, clickedWindow == window {
                return
            }
            
            // Close the window
            self.closeHistoryWindow()
        }
    }
    
    func closeHistoryWindow() {
        guard let window = historyWindow, let screen = NSScreen.main else { return }
        
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // Animate the window sliding out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(
                NSRect(
                    x: screen.visibleFrame.maxX,
                    y: window.frame.minY,
                    width: window.frame.width,
                    height: window.frame.height
                ),
                display: true
            )
        }, completionHandler: {
            self.historyWindow?.orderOut(nil)
            self.historyWindow = nil
        })
    }
    
    // Window delegate method to handle window closing
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == historyWindow {
            // Remove event monitor
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            historyWindow = nil
        }
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
        // If history window exists and is visible, close it
        if let window = historyWindow, window.isVisible {
            closeHistoryWindow()
        } else {
            // Otherwise, show it
            showHistoryWindow()
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
    var mainWindow: NSWindow?
    var settingsWindow: NSWindow?
    @Published var showNumbersOnly: Bool = false {
        didSet {
            UserDefaults.standard.set(showNumbersOnly, forKey: "ShowNumbersOnly")
            appDelegate.updateKeystrokesCount()
        }
    }

    init(mainWindow: NSWindow?, appDelegate: AppDelegate) {
        self.mainWindow = mainWindow
        self.appDelegate = appDelegate
        self.showNumbersOnly = UserDefaults.standard.bool(forKey: "ShowNumbersOnly")
        buildMenu()
    }

    func buildMenu() {
        menu = NSMenu()

        // Just keep the website and quit items
        let websiteItem = NSMenuItem(title: "Website", action: #selector(goToWebsite), keyEquivalent: "")
        websiteItem.target = self

        menu.addItem(websiteItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(terminateApp), keyEquivalent: "q")
    }
    
    @objc func showHistory() {
        AppDelegate.instance.showHistoryWindow()
    }

    @objc func goToWebsite() {
        if let url = URL(string: "https://github.com/MarcusDelvecchio/macos-keystroke-counter") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func terminateApp() {
        NSApplication.shared.terminate(self)
    }

    @objc func toggleMenu() {
        // Get a direct reference to the app delegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.showHistoryWindow()
        }
    }
}
