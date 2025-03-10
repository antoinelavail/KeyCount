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

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    var activity: NSObjectProtocol?
    var mainWindow: NSWindow!
    var historyWindow: NSWindow?
    static private(set) var instance: AppDelegate!
    lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var updateInterval = Int(UserDefaults.standard.string(forKey: "updateInterval") ?? "30") ?? 30
    
    // Variables for maintaining keystroke data
    var keystrokeData: [Int] = []
    var currentTimeIndex: Int = 0
    var endpointURL: String = ""
    
    // The number of keystrokes at the beginning of the interval, so that when we send the data we can add the keystrokes from the leystroke data on to this value incrementally
    var keystrokesAtBeginningOfInterval: Int = 0
    
    // how precise the key detection logic is. keystrokeData data will be an array of Integers where each Int represents the number of keystrokes that took place in each period. If updatePrecision = 4, then it will be the number of keystrokes in each 250ms period (4 periods per second)
    var updatePrecision: Int = 20
    
    // keys for UserDefaults data
    let sendingUpdatesEnabledKey = "sendingUpdatesEnabled"
    let updateEndpointURIKey = "updateEndpointURI"
    let updateIntervalKey = "updateInterval"
    
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
        self.keystrokesAtBeginningOfInterval = UserDefaults.standard.integer(forKey: "keystrokesToday")
        self.totalKeystrokes = UserDefaults.standard.integer(forKey: "totalKeystrokes")
        self.endpointURL = UserDefaults.standard.string(forKey: updateEndpointURIKey) ?? ""
        self.keystrokeData = Array(repeating: 0, count: updateInterval * updatePrecision)
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
                    string: "\(keystrokeCount) keystrokes",
                    attributes: [NSAttributedString.Key.baselineOffset: offset]
                )
            }
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

        statusItem.menu = menu.menu
        statusItem.button?.action = #selector(menu.toggleMenu)

        // Request accessibility permissions
        requestAccessibilityPermission()

        // Register for key events using event tap
        setupEventTap()
        
        // If sending updates is enabled start timer to send update data after every interval
        if UserDefaults.standard.bool(forKey: self.sendingUpdatesEnabledKey) {
            setupTimeIndexIncrementer()
        }
        
        // Check if we need to reset daily count
        if clearKeystrokesDaily && KeystrokeHistoryManager.shared.resetDailyCountIfNeeded() {
            keystrokeCount = 0
            updateKeystrokesCount()
        }
    }
    
    @objc func showHistoryWindow() {
        if historyWindow == nil {
            historyWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            historyWindow?.title = "Keystroke History"
            historyWindow?.center()
            historyWindow?.delegate = self  // Set the delegate
            
            let hostingView = NSHostingView(rootView: KeystrokeChartView())
            historyWindow?.contentView = hostingView
        }
        
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Window delegate method to handle window closing
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == historyWindow {
            // When window closes, set reference to nil
            historyWindow = nil
        }
    }
    
    func updateKeystrokesCount() {
        if let button = statusItem.button {
            let displayString = menu?.showNumbersOnly == true ? "\(keystrokeCount)" : "\(keystrokeCount) keystrokes"
            
            button.title = displayString

            // Calculate the minimum width based on the number of digits
            var minWidth: CGFloat = 110.0
            let digitCount = "\(keystrokeCount)".count

            if digitCount >= 4 {
                minWidth += CGFloat(digitCount - 4) * 10.0
            }

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
        keystrokeCount += 1
        totalKeystrokes += 1
        updateKeystrokesCount()

        // Check if it's a new day
        if clearKeystrokesDaily && KeystrokeHistoryManager.shared.resetDailyCountIfNeeded() {
            // Save yesterday's count
            KeystrokeHistoryManager.shared.saveDailyCount(keystrokeCount)
            
            // Reset daily keystrokes count
            keystrokeCount = 1  // Set to 1 because we just counted a keystroke
        }
    }
    
    func setupTimeIndexIncrementer() {
        // Create a timer that calls the incrementTimeIndex method [updatePrecision] times per second
        let timer = Timer.scheduledTimer(timeInterval: 1.0/Double(updatePrecision), target: self, selector: #selector(incrementTimeIndex), userInfo: nil, repeats: true)
        
        // Run the timer on the current run loop
        RunLoop.current.add(timer, forMode: .common)
    }
    
    @objc func incrementTimeIndex() {
        // Increment currentTimeIndex
        currentTimeIndex += 1
        
        // Uncommment print statement for timer increment debugging
        // print("Timestamp: \(Date()) - Current Time Index: \(currentTimeIndex)")
    }
    
    func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let mask = CGEventMask(eventMask) | CGEventFlags.maskCommand.rawValue

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return nil
                }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                appDelegate.handleEvent(event)

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

    @objc func terminateApp() {
        UserDefaults.standard.synchronize()
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        NSApplication.shared.terminate(self)
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

        let resetItem = NSMenuItem(title: "Reset Keystrokes", action: #selector(resetKeystrokes), keyEquivalent: "")
        resetItem.target = self

        let historyItem = NSMenuItem(title: "View History", action: #selector(showHistory), keyEquivalent: "h")
        historyItem.target = self

        let numbersOnlyItem = NSMenuItem(title: "Toggle Number Only", action: #selector(toggleShowNumbersOnly), keyEquivalent: "")
        numbersOnlyItem.target = self
        numbersOnlyItem.state = showNumbersOnly ? .on : .off

        let websiteItem = NSMenuItem(title: "Website", action: #selector(goToWebsite), keyEquivalent: "")
        websiteItem.target = self

        menu.addItem(resetItem)
        menu.addItem(historyItem)
        menu.addItem(numbersOnlyItem)
        menu.addItem(websiteItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(terminateApp), keyEquivalent: "q")
    }
    
    @objc func showHistory() {
        AppDelegate.instance.showHistoryWindow()
    }

    @objc func resetKeystrokes() {
        let confirmResetAlert = NSAlert()
        confirmResetAlert.messageText = "Reset Keystrokes"
        confirmResetAlert.informativeText = "Are you sure you want to reset the keystrokes count?"
        confirmResetAlert.addButton(withTitle: "Reset")
        confirmResetAlert.addButton(withTitle: "Cancel")
        confirmResetAlert.alertStyle = .warning

        let response = confirmResetAlert.runModal()

        if response == .alertFirstButtonReturn {
            appDelegate.keystrokeCount = 0
            appDelegate.updateKeystrokesCount()
        }
    }

    @objc func goToWebsite() {
        if let url = URL(string: "https://github.com/MarcusDelvecchio/macos-keystroke-counter") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func toggleShowNumbersOnly() {
        showNumbersOnly.toggle()
    }

    @objc func terminateApp() {
        NSApplication.shared.terminate(self)
    }

    @objc func toggleMenu() {
        if let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength).button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
        }
    }
}


struct KeystrokeDataObject: Codable {
    let timestamp: String
    let intervalData: [Int]
    let keystrokeCountBefore: Int
    let keystrokeCountAfter: Int
    let intervalLength: Int
    let updatePrecision: Int
}
