import Foundation
import CoreGraphics

// Define a struct to represent a keyboard shortcut
struct KeyboardShortcut: Hashable, Codable {
    let keyCode: UInt16
    let modifiers: UInt64  // Using UInt64 to match CGEventFlags
    
    // Add explicit Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }
    
    static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
    
    func description() -> String {
        var parts: [String] = []
        
        // Add modifier symbols in a consistent order
        if modifiers & CGEventFlags.maskControl.rawValue != 0 {
            parts.append("⌃")
        }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 {
            parts.append("⌥")
        }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 {
            parts.append("⇧")
        }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 {
            parts.append("⌘")
        }
        
        // Add the key
        parts.append(KeyUsageTracker.shared.keyCodeToString(keyCode))
        
        return parts.joined(separator: "+")
    }
}

// Time range enum
enum TimeRange {
    case today
    case lastWeek
    case lastMonth
    case allTime
    
    var description: String {
        switch self {
        case .today: return "Today"
        case .lastWeek: return "7 Days"
        case .lastMonth: return "30 Days"
        case .allTime: return "All Time"
        }
    }
}

class KeyUsageTracker: ObservableObject {
    static let shared = KeyUsageTracker()
    
    @Published private var keyUsageCounts: [UInt16: Int] = [:]
    @Published private var shortcutUsageCounts: [KeyboardShortcut: Int] = [:]
    @Published private var keyUsageTimestamps: [UInt16: [Date]] = [:]
    @Published private var shortcutUsageTimestamps: [KeyboardShortcut: [Date]] = [:]
    private let userDefaultsKey = "keyUsageCounts"
    private let shortcutUserDefaultsKey = "shortcutUsageCounts"
    private let keyTimestampsKey = "keyUsageTimestamps"
    private let shortcutTimestampsKey = "shortcutUsageTimestamps"
    
    init() {
        loadData()
    }
    
    func recordKeyPress(keyCode: UInt16) {
        keyUsageCounts[keyCode, default: 0] += 1
        
        // Store timestamp
        let now = Date()
        if keyUsageTimestamps[keyCode] == nil {
            keyUsageTimestamps[keyCode] = []
        }
        keyUsageTimestamps[keyCode]?.append(now)
        
        saveData()
    }
    
    func recordShortcut(keyCode: UInt16, modifiers: UInt64) {
        // Filter to include only the relevant modifier flags
        let relevantModifiers = modifiers & (
            CGEventFlags.maskCommand.rawValue |
            CGEventFlags.maskShift.rawValue |
            CGEventFlags.maskAlternate.rawValue |
            CGEventFlags.maskControl.rawValue
        )
        
        // Only record if we actually have modifiers
        if relevantModifiers != 0 {
            let shortcut = KeyboardShortcut(keyCode: keyCode, modifiers: relevantModifiers)
            shortcutUsageCounts[shortcut, default: 0] += 1
            
            // Store timestamp
            let now = Date()
            if shortcutUsageTimestamps[shortcut] == nil {
                shortcutUsageTimestamps[shortcut] = []
            }
            shortcutUsageTimestamps[shortcut]?.append(now)
            
            saveData()
        }
    }
    
    func getKeyCount(for keyCode: UInt16) -> Int {
        return keyUsageCounts[keyCode] ?? 0
    }
    
    func getShortcutCount(for shortcut: KeyboardShortcut) -> Int {
        return shortcutUsageCounts[shortcut] ?? 0
    }
    
    func getMaxCount() -> Int {
        return keyUsageCounts.values.max() ?? 0
    }
    
    func getCombinedKeyCount(for keyCode: UInt16) -> Int {
        // Start with direct key presses
        var totalCount = getKeyCount(for: keyCode)
        
        // If this is a modifier key, also count shortcuts that use it
        let commandKey: UInt16 = 55
        let shiftKey: UInt16 = 56
        let optionKey: UInt16 = 58
        let controlKey: UInt16 = 59
        
        // Count shortcuts that use this key
        for (shortcut, count) in shortcutUsageCounts {
            // If the shortcut uses this key directly
            if shortcut.keyCode == keyCode {
                totalCount += count
            }
            
            // If it's a modifier key and the shortcut uses this modifier
            if keyCode == commandKey && (shortcut.modifiers & CGEventFlags.maskCommand.rawValue) != 0 {
                totalCount += count
            } else if keyCode == shiftKey && (shortcut.modifiers & CGEventFlags.maskShift.rawValue) != 0 {
                totalCount += count
            } else if keyCode == optionKey && (shortcut.modifiers & CGEventFlags.maskAlternate.rawValue) != 0 {
                totalCount += count
            } else if keyCode == controlKey && (shortcut.modifiers & CGEventFlags.maskControl.rawValue) != 0 {
                totalCount += count
            }
        }
        
        return totalCount
    }
    
    func getMaxShortcutCount() -> Int {
        return shortcutUsageCounts.values.max() ?? 0
    }
    
    func getKeyCountForTimeRange(for keyCode: UInt16, timeRange: TimeRange) -> Int {
        guard let timestamps = keyUsageTimestamps[keyCode] else {
            return 0
        }
        
        let dateLimit: Date?
        switch timeRange {
        case .today:
            dateLimit = Calendar.current.startOfDay(for: Date())
        case .lastWeek:
            dateLimit = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .lastMonth:
            dateLimit = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case .allTime:
            dateLimit = nil
        }
        
        if let limit = dateLimit {
            return timestamps.filter { $0 >= limit }.count
        } else {
            return getKeyCount(for: keyCode)
        }
    }

    func getShortcutCountForTimeRange(for shortcut: KeyboardShortcut, timeRange: TimeRange) -> Int {
        guard let timestamps = shortcutUsageTimestamps[shortcut] else {
            return 0
        }
        
        let dateLimit: Date?
        switch timeRange {
        case .today:
            dateLimit = Calendar.current.startOfDay(for: Date())
        case .lastWeek:
            dateLimit = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .lastMonth:
            dateLimit = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case .allTime:
            dateLimit = nil
        }
        
        if let limit = dateLimit {
            return timestamps.filter { $0 >= limit }.count
        } else {
            return getShortcutCount(for: shortcut)
        }
    }
    
    func getTopKeys(count: Int) -> [(keyCode: UInt16, count: Int, label: String)] {
        // Get keys sorted by usage (most used first)
        let sortedKeys = keyUsageCounts.sorted { $0.value > $1.value }
        
        // Take the top N keys
        let topKeys = sortedKeys.prefix(count)
        
        // Map to return array with key labels
        return topKeys.map { (keyCode: $0.key, count: $0.value, label: keyCodeToString($0.key)) }
    }
    
    func getTopKeysForTimeRange(count: Int, timeRange: TimeRange) -> [(keyCode: UInt16, count: Int, label: String)] {
        if timeRange == .allTime {
            return getTopKeys(count: count)
        }
        
        // Calculate counts for each key in the specified time range
        var timeRangeCounts: [UInt16: Int] = [:]
        for (keyCode, _) in keyUsageTimestamps {
            let countForRange = getKeyCountForTimeRange(for: keyCode, timeRange: timeRange)
            if countForRange > 0 {
                timeRangeCounts[keyCode] = countForRange
            }
        }
        
        // Sort and return top keys
        let sortedKeys = timeRangeCounts.sorted { $0.value > $1.value }
        let topKeys = sortedKeys.prefix(count)
        return topKeys.map { (keyCode: $0.key, count: $0.value, label: keyCodeToString($0.key)) }
    }
    
    func getTopShortcuts(count: Int) -> [(shortcut: KeyboardShortcut, count: Int, description: String)] {
        // Get shortcuts sorted by usage (most used first)
        let sortedShortcuts = shortcutUsageCounts.sorted { $0.value > $1.value }
        
        // Take the top N shortcuts
        let topShortcuts = sortedShortcuts.prefix(count)
        
        // Map to return array with shortcut descriptions
        return topShortcuts.map { (shortcut: $0.key, count: $0.value, description: $0.key.description()) }
    }
    
    func getTopShortcutsForTimeRange(count: Int, timeRange: TimeRange) -> [(shortcut: KeyboardShortcut, count: Int, description: String)] {
        if timeRange == .allTime {
            return getTopShortcuts(count: count)
        }
        
        // Calculate counts for each shortcut in the specified time range
        var timeRangeCounts: [KeyboardShortcut: Int] = [:]
        for (shortcut, _) in shortcutUsageTimestamps {
            let countForRange = getShortcutCountForTimeRange(for: shortcut, timeRange: timeRange)
            if countForRange > 0 {
                timeRangeCounts[shortcut] = countForRange
            }
        }
        
        // Sort and return top shortcuts
        let sortedShortcuts = timeRangeCounts.sorted { $0.value > $1.value }
        let topShortcuts = sortedShortcuts.prefix(count)
        return topShortcuts.map { (shortcut: $0.key, count: $0.value, description: $0.key.description()) }
    }
    
    func keyCodeToString(_ keyCode: UInt16) -> String {
        // For AZERTY keyboard
        switch keyCode {
        case 0: return "Q"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "W"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "A"
        case 13: return "Z"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "&"
        case 19: return "é"
        case 20: return "\""
        case 21: return "'"
        case 22: return "§"
        case 23: return "("
        case 24: return "="
        case 25: return "ç"
        case 26: return "è"
        case 27: return ")"
        case 28: return "!"
        case 29: return "à"
        case 30: return "$"
        case 31: return "O"
        case 32: return "U"
        case 33: return "^"
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "ù"
        case 40: return "K"
        case 41: return "M"
        case 42: return "*"
        case 43: return ","
        case 44: return ":"
        case 45: return "N"
        case 46: return "M"
        case 47: return ";"
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 55: return "Command"
        case 56: return "Shift"
        case 57: return "Caps Lock"
        case 58: return "Option"
        case 59: return "Control"
        case 63: return "Fn"
        case 96...111: return "F\(keyCode - 95)"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default: return "Key \(keyCode)"
        }
    }
    
    func saveData() {
        // Save existing counts
        if let encodedKeyData = try? JSONEncoder().encode(keyUsageCounts) {
            UserDefaults.standard.set(encodedKeyData, forKey: userDefaultsKey)
        }
        
        if let encodedShortcutData = try? JSONEncoder().encode(shortcutUsageCounts) {
            UserDefaults.standard.set(encodedShortcutData, forKey: shortcutUserDefaultsKey)
        }
        
        // Save new timestamp data
        if let encodedKeyTimestamps = try? JSONEncoder().encode(keyUsageTimestamps) {
            UserDefaults.standard.set(encodedKeyTimestamps, forKey: keyTimestampsKey)
        }
        
        if let encodedShortcutTimestamps = try? JSONEncoder().encode(shortcutUsageTimestamps) {
            UserDefaults.standard.set(encodedShortcutTimestamps, forKey: shortcutTimestampsKey)
        }
    }
    
    // Add this method to reset daily data
    func resetDailyData() {
        // Clear today's timestamps but keep the counts
        let today = Calendar.current.startOfDay(for: Date())
        
        // For each key, filter out today's timestamps
        for (keyCode, timestamps) in keyUsageTimestamps {
            keyUsageTimestamps[keyCode] = timestamps.filter { $0 < today }
        }
        
        // For each shortcut, filter out today's timestamps
        for (shortcut, timestamps) in shortcutUsageTimestamps {
            shortcutUsageTimestamps[shortcut] = timestamps.filter { $0 < today }
        }
        
        // Save the updated data
        saveData()
    }
    
    func loadData() {
        if let savedKeyData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedKeyCounts = try? JSONDecoder().decode([UInt16: Int].self, from: savedKeyData) {
            keyUsageCounts = decodedKeyCounts
        }
        
        if let savedShortcutData = UserDefaults.standard.data(forKey: shortcutUserDefaultsKey),
           let decodedShortcutCounts = try? JSONDecoder().decode([KeyboardShortcut: Int].self, from: savedShortcutData) {
            shortcutUsageCounts = decodedShortcutCounts
        }
        
        // Load timestamp data
        if let savedKeyTimestamps = UserDefaults.standard.data(forKey: keyTimestampsKey),
           let decodedKeyTimestamps = try? JSONDecoder().decode([UInt16: [Date]].self, from: savedKeyTimestamps) {
            keyUsageTimestamps = decodedKeyTimestamps
        }
        
        if let savedShortcutTimestamps = UserDefaults.standard.data(forKey: shortcutTimestampsKey),
           let decodedShortcutTimestamps = try? JSONDecoder().decode([KeyboardShortcut: [Date]].self, from: savedShortcutTimestamps) {
            shortcutUsageTimestamps = decodedShortcutTimestamps
        }
    }
}
