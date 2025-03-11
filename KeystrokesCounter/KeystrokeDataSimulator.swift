#!/usr/bin/swift

import Foundation

struct KeyboardShortcut: Hashable, Codable {
    let keyCode: UInt16
    let modifiers: UInt64
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }
}

// Get the UserDefaults for your app
let defaults = UserDefaults.standard

// Date formatter for history keys
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd"

// Today's date
let today = Date()

// Common keys on AZERTY keyboard
let commonKeyCodes: [UInt16] = [12, 13, 14, 15, 17, 16, 32, 34, 0, 1, 2, 3, 5, 4, 38, 40, 37, 6, 7, 8, 9, 11, 49]
let keysFrequency: [UInt16: Double] = [
    14: 0.15, // E
    12: 0.08, // A
    1: 0.08,  // S
    0: 0.08,  // Q
    32: 0.07, // U
    34: 0.07, // I
    15: 0.06, // R
    49: 0.18, // Space
    // Other keys will use random values
]

// Common shortcuts
let commonShortcuts: [(keyCode: UInt16, modifiers: UInt64)] = [
    (13, 1 << 20), // Command+Z (Undo)
    (7, 1 << 20),  // Command+X (Cut)
    (8, 1 << 20),  // Command+C (Copy)
    (9, 1 << 20),  // Command+V (Paste)
    (0, 1 << 20),  // Command+Q (Quit)
    (1, 1 << 20),  // Command+S (Save)
    (15, 1 << 20), // Command+R (Reload)
    (3, 1 << 20),  // Command+F (Find)
]

// Generate keystroke data
var keyUsageCounts: [UInt16: Int] = [:]
var shortcutUsageCounts: [KeyboardShortcut: Int] = [:]
var keyUsageTimestamps: [UInt16: [Date]] = [:]
var shortcutUsageTimestamps: [KeyboardShortcut: [Date]] = [:]

// Clear any existing data
defaults.removeObject(forKey: "keyUsageCounts")
defaults.removeObject(forKey: "shortcutUsageCounts")
defaults.removeObject(forKey: "keyUsageTimestamps")
defaults.removeObject(forKey: "shortcutUsageTimestamps")

// Generator function for a single day
func generateDayData(date: Date, baseKeystrokeCount: Int) {
    let keystrokeCount = baseKeystrokeCount + Int.random(in: -200...200)
    let dayKey = "keystrokesHistory_" + dateFormatter.string(from: date)
    defaults.set(keystrokeCount, forKey: dayKey)
    
    print("Generated \(keystrokeCount) keystrokes for \(dateFormatter.string(from: date))")
    
    // Generate individual keystrokes
    for _ in 0..<keystrokeCount {
        // Select a key based on frequency
        let keyCode: UInt16
        if Double.random(in: 0...1) < 0.8 {
            // Use weighted selection
            let rand = Double.random(in: 0...1)
            var cumulativeProbability = 0.0
            var selectedKey: UInt16 = commonKeyCodes.randomElement()!
            
            for (key, probability) in keysFrequency {
                cumulativeProbability += probability
                if rand <= cumulativeProbability {
                    selectedKey = key
                    break
                }
            }
            keyCode = selectedKey
        } else {
            // Use random key
            keyCode = UInt16.random(in: 0...50)
        }
        
        // Record key press
        keyUsageCounts[keyCode, default: 0] += 1
        
        // Record timestamp
        let timestamp = Calendar.current.date(
            byAdding: .second, 
            value: -Int.random(in: 0..<86400), 
            to: date
        )!
        
        if keyUsageTimestamps[keyCode] == nil {
            keyUsageTimestamps[keyCode] = []
        }
        keyUsageTimestamps[keyCode]?.append(timestamp)
    }
    
    // Generate shortcut data
    let shortcutCount = keystrokeCount / 20 // About 5% of keystrokes are shortcuts
    for _ in 0..<shortcutCount {
        let shortcutInfo = commonShortcuts.randomElement()!
        let shortcut = KeyboardShortcut(keyCode: shortcutInfo.keyCode, modifiers: shortcutInfo.modifiers)
        
        shortcutUsageCounts[shortcut, default: 0] += 1
        
        // Record timestamp
        let timestamp = Calendar.current.date(
            byAdding: .second, 
            value: -Int.random(in: 0..<86400), 
            to: date
        )!
        
        if shortcutUsageTimestamps[shortcut] == nil {
            shortcutUsageTimestamps[shortcut] = []
        }
        shortcutUsageTimestamps[shortcut]?.append(timestamp)
    }
}

// Generate data for the past 3 days
print("Generating keystroke data for the past 3 days...")

// Today (lighter usage)
let todayDate = today
generateDayData(date: todayDate, baseKeystrokeCount: 500)

// Yesterday (medium usage)
let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: today)!
generateDayData(date: yesterdayDate, baseKeystrokeCount: 2000)

// Day before yesterday (heavier usage)
let twoDaysAgoDate = Calendar.current.date(byAdding: .day, value: -2, to: today)!
generateDayData(date: twoDaysAgoDate, baseKeystrokeCount: 1500)

// Save to UserDefaults
if let encodedKeyData = try? JSONEncoder().encode(keyUsageCounts) {
    defaults.set(encodedKeyData, forKey: "keyUsageCounts")
}

if let encodedShortcutData = try? JSONEncoder().encode(shortcutUsageCounts) {
    defaults.set(encodedShortcutData, forKey: "shortcutUsageCounts")
}

if let encodedKeyTimestamps = try? JSONEncoder().encode(keyUsageTimestamps) {
    defaults.set(encodedKeyTimestamps, forKey: "keyUsageTimestamps")
}

if let encodedShortcutTimestamps = try? JSONEncoder().encode(shortcutUsageTimestamps) {
    defaults.set(encodedShortcutTimestamps, forKey: "shortcutUsageTimestamps")
}

// Set last date
defaults.set(dateFormatter.string(from: todayDate), forKey: "lastDate")

print("Data generation complete!")
print("Run your app to see the simulated data.")
