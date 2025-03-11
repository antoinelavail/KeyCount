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

// Extension to check if a key exists in UserDefaults
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
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

    @Published var keystrokeCount: Int {
        didSet {
            UserDefaults.standard.set(keystrokeCount, forKey: "keystrokesToday")
        }
    }

    private var eventTap: CFMachPort?
    var menu: ApplicationMenu!

    override init() {
        self.keystrokeCount = UserDefaults.standard.integer(forKey: "keystrokesToday")
                
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
        
        // Set direct click handling
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.target = self

        // Request accessibility permissions
        requestAccessibilityPermission()

        // Register for key events using event tap
        setupEventTap()
        
        // Setup statsWindow at launch time
        initializeStatsWindow()
        
        // Check if we need to reset daily count
        if KeystrokeHistoryManager.shared.resetDailyCountIfNeeded() {
            keystrokeCount = 0
            updateKeystrokesCount()
            
            // Reset today's key usage data
            KeyUsageTracker.shared.resetDailyData()
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
        
        // Create a NSPanel instead of NSWindow - this is better for non-activating UI
        let panel = NSPanel(
            contentRect: NSRect(
                x: screenRect.maxX, // Position it offscreen to the right
                y: screenRect.maxY - windowHeight - 20,
                width: windowWidth,
                height: windowHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel], // Add nonactivatingPanel 
            backing: .buffered,
            defer: false
        )
        
        // Configure the panel
        panel.backgroundColor = NSColor.clear
        panel.alphaValue = 0.0
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating // Better for showing over other windows
        panel.delegate = self
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true // Important!
        panel.titlebarAppearsTransparent = true
        
        // Assign to statsWindow
        statsWindow = panel
        
        // Configure the view with a notification publisher for animation timing
        let animationManager = WindowAnimationManager()
        let hostingController = NSHostingController(
            rootView: KeystrokeChartView(highlightToday: true, todayCount: keystrokeCount)
                .environmentObject(animationManager)
        )
        
        // Set the hosting controller as the window's content view controller
        statsWindow?.contentViewController = hostingController
        
        // Apply styling to the content view
        statsWindow?.contentView?.wantsLayer = true
        statsWindow?.contentView?.layer?.cornerRadius = 12
        statsWindow?.contentView?.layer?.masksToBounds = true
        
        // Make corners rounded
        statsWindow?.contentView?.wantsLayer = true
        statsWindow?.contentView?.layer?.cornerRadius = 12
        statsWindow?.contentView?.layer?.masksToBounds = false
        statsWindow?.contentView?.layer?.shadowOpacity = 0.3
        statsWindow?.contentView?.layer?.shadowRadius = 8
        statsWindow?.contentView?.layer?.shadowOffset = CGSize(width: 0, height: -3)
    }
    
    func updateStatsView() {
        if let window = statsWindow {
            // Create a new animation manager to trigger fresh animations
            let animationManager = WindowAnimationManager()
            
            if let hostingController = window.contentViewController as? NSHostingController<KeystrokeChartView> {
                // Update the existing view's properties
                hostingController.rootView = KeystrokeChartView(highlightToday: true, todayCount: keystrokeCount)
                    .environmentObject(animationManager) as! KeystrokeChartView
            } else {
                // Create a new controller only if needed (first time)
                let hostingController = NSHostingController(
                    rootView: KeystrokeChartView(highlightToday: true, todayCount: keystrokeCount)
                        .environmentObject(animationManager)
                )
                window.contentViewController = hostingController
            }
            
            // Trigger animations with a slight delay to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now()) {
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
        
        // First refresh data, then show window when data is ready
        StatsDataStore.shared.forceRefresh { [weak self] in
            guard let self = self else { return }
            
            // Update the existing content view instead of replacing it
            self.updateStatsView()
            
            // IMPORTANT: First explicitly position the window offscreen to the right
            // This ensures the animation starts from the correct position
            self.statsWindow?.setFrame(
                NSRect(
                    x: screenRect.maxX, // Start completely offscreen
                    y: screenRect.maxY - windowHeight - 20, // Correct vertical position
                    width: windowWidth,
                    height: windowHeight
                ),
                display: false // Don't display yet
            )
            
            // Show the window and bring it to the front - use orderFrontRegardless
            self.statsWindow?.orderFrontRegardless() // Changed from orderFront(nil)
            // Remove makeKey() call as it's unnecessary and causing warnings
            
            // Combined fade + RIGHT-TO-LEFT slide animation
            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                
                // Animate both position and opacity
                self.statsWindow?.animator().setFrame(
                    NSRect(
                        x: screenRect.maxX - windowWidth - 20,
                        y: screenRect.maxY - windowHeight - 20,
                        width: windowWidth,
                        height: windowHeight
                    ),
                    display: true
                )
                self.statsWindow?.animator().alphaValue = 1.0
            })
            
            // Set up event monitoring to close the window when focus is lost
            self.setupEventMonitoring()
        }
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
            let displayString = "\(formattedCount) ⌨️"
            
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
            updateKeystrokesCount()

            // Record the key press
            KeyUsageTracker.shared.recordKeyPress(keyCode: keyCode)
        }

        // Save current day's count
        KeystrokeHistoryManager.shared.saveCurrentDayCount(keystrokeCount)
        
        // If stats window is visible, update data (throttled to every few keystrokes)
        if let window = statsWindow, window.isVisible {
            StatsDataStore.shared.refreshData()
        }

        // Check if it's a new day
        if KeystrokeHistoryManager.shared.resetDailyCountIfNeeded() {
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

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
}
