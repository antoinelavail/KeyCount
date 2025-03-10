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

class KeyUsageTracker: ObservableObject {
    static let shared = KeyUsageTracker()
    
    @Published private var keyUsageCounts: [UInt16: Int] = [:]
    @Published private var shortcutUsageCounts: [KeyboardShortcut: Int] = [:]
    private let userDefaultsKey = "keyUsageCounts"
    private let shortcutUserDefaultsKey = "shortcutUsageCounts"
    
    init() {
        loadData()
    }
    
    func recordKeyPress(keyCode: UInt16) {
        keyUsageCounts[keyCode, default: 0] += 1
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
            
            // Debug print to see if shortcut is being recorded
            print("Recorded shortcut: \(shortcut.description()) - Count: \(shortcutUsageCounts[shortcut, default: 0])")
            
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
    
    func getMaxShortcutCount() -> Int {
        return shortcutUsageCounts.values.max() ?? 0
    }
    
    func getTopKeys(count: Int) -> [(keyCode: UInt16, count: Int, label: String)] {
        // Get keys sorted by usage (most used first)
        let sortedKeys = keyUsageCounts.sorted { $0.value > $1.value }
        
        // Take the top N keys
        let topKeys = sortedKeys.prefix(count)
        
        // Map to return array with key labels
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
        if let encodedKeyData = try? JSONEncoder().encode(keyUsageCounts) {
            UserDefaults.standard.set(encodedKeyData, forKey: userDefaultsKey)
        }
        
        if let encodedShortcutData = try? JSONEncoder().encode(shortcutUsageCounts) {
            UserDefaults.standard.set(encodedShortcutData, forKey: shortcutUserDefaultsKey)
        }
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
    }
}
