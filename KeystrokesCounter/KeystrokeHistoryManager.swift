import Foundation

class KeystrokeHistoryManager {
    static let shared = KeystrokeHistoryManager()
    
    private let userDefaults = UserDefaults.standard
    private let dateFormatter: DateFormatter
    
    // Keys
    private let keystrokeHistoryPrefix = "keystrokesHistory_"
    private let lastDateKey = "lastDate"
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // Get current date key
    var currentDateKey: String {
        return dateFormatter.string(from: Date())
    }
    
    // Save today's keystroke count
    func saveDailyCount(_ count: Int) {
        let key = keystrokeHistoryPrefix + currentDateKey
        userDefaults.set(count, forKey: key)
        userDefaults.set(currentDateKey, forKey: lastDateKey)
    }
    
    // Get keystroke history for the last n days
    func getKeystrokeHistory(days: Int) -> [(date: String, count: Int)] {
        var result: [(date: String, count: Int)] = []
        
        // First get history for specific days (backward compatibility)
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateString = dateFormatter.string(from: date)
                let key = keystrokeHistoryPrefix + dateString
                let count = userDefaults.integer(forKey: key)
                // Only add non-zero counts to avoid cluttering the chart
                if count > 0 {
                    result.append((date: dateString, count: count))
                }
            }
        }
        
        // Now also find any other keystroke history entries in UserDefaults
        let allDefaults = userDefaults.dictionaryRepresentation()
        for (key, value) in allDefaults {
            if key.hasPrefix(keystrokeHistoryPrefix) {
                let dateString = String(key.dropFirst(keystrokeHistoryPrefix.count))
                
                // Skip dates we've already added
                if !result.contains(where: { $0.date == dateString }) {
                    // Make sure the value is an integer
                    if let count = value as? Int, count > 0 {
                        result.append((date: dateString, count: count))
                    }
                }
            }
        }
        
        // Sort by date (ascending)
        return result.sorted(by: { $0.date < $1.date })
    }
    
    // Check if it's a new day
    func isNewDay() -> Bool {
        if let lastDate = userDefaults.string(forKey: lastDateKey) {
            return lastDate != currentDateKey
        }
        return true
    }
    
    // Reset daily count for a new day
    func resetDailyCountIfNeeded() -> Bool {
        if isNewDay() {
            // Save yesterday's count before resetting
            if let lastDate = userDefaults.string(forKey: lastDateKey) {
                let yesterdayKey = keystrokeHistoryPrefix + lastDate
                let yesterdayCount = userDefaults.integer(forKey: "keystrokesToday")
                userDefaults.set(yesterdayCount, forKey: yesterdayKey)
                
                // Add this log to debug
                print("Saved \(yesterdayCount) keystrokes for \(lastDate)")
            }
            
            // Update the last date to today
            userDefaults.set(currentDateKey, forKey: lastDateKey)
            
            // Reset keystrokesToday to 0
            userDefaults.set(0, forKey: "keystrokesToday")
            
            return true
        }
        return false
    }
    
    // Add this method to manually save today's count
    func saveCurrentDayCount(_ count: Int) {
        let key = keystrokeHistoryPrefix + currentDateKey
        userDefaults.set(count, forKey: key)
        print("Manually saved \(count) keystrokes for \(currentDateKey)")
    }
}
