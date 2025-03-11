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
        
        // Get current date and calculate cutoff date
        let calendar = Calendar.current
        let today = Date()
        let cutoffDate = calendar.date(byAdding: .day, value: -(days-1), to: today)!
        let cutoffDateString = dateFormatter.string(from: cutoffDate)
        
        // Get all history entries
        let allDefaults = userDefaults.dictionaryRepresentation()
        for (key, value) in allDefaults {
            if key.hasPrefix(keystrokeHistoryPrefix) {
                let dateString = String(key.dropFirst(keystrokeHistoryPrefix.count))
                
                // Only include dates within the selected time period
                if dateString >= cutoffDateString {
                    if let count = value as? Int, count > 0 {
                        result.append((date: dateString, count: count))
                    }
                }
            }
        }
        
        // Make sure we include all days in the range, even those with 0 keystrokes
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateString = dateFormatter.string(from: date)
                if !result.contains(where: { $0.date == dateString }) {
                    // Add with 0 count
                    result.append((date: dateString, count: 0))
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
