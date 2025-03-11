import SwiftUI
import Combine

class StatsDataStore: ObservableObject {
    static let shared = StatsDataStore()
    
    // Published properties for UI components
    @Published var historyData: [(date: String, count: Int)] = []
    @Published var topKeys: [(keyCode: UInt16, count: Int, label: String)] = []
    @Published var topShortcuts: [(shortcut: KeyboardShortcut, count: Int, description: String)] = []
    @Published var lastUpdateTime = Date()
    @Published var isRefreshing = false
    
    // Days selection for history
    @Published var selectedDays: Int = 7
    @Published var selectedKeysTimeRange: TimeRange = .today
    @Published var selectedShortcutsTimeRange: TimeRange = .today
    
    private init() {
        // Initial refresh
        refreshData()
    }
    
    func refreshData(completion: (() -> Void)? = nil) {
        isRefreshing = true
        
        // Perform refresh on background thread for better UI responsiveness
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                completion?()
                return 
            }
            
            // Refresh all data types
            let newHistoryData = KeystrokeHistoryManager.shared.getKeystrokeHistory(days: self.selectedDays)
            let newTopKeys = KeyUsageTracker.shared.getTopKeysForTimeRange(count: 10, timeRange: self.selectedKeysTimeRange)
            let newTopShortcuts = KeyUsageTracker.shared.getTopShortcutsForTimeRange(count: 10, timeRange: self.selectedShortcutsTimeRange)
            
            // Update today's count in history data
            var updatedHistoryData = newHistoryData
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let today = dateFormatter.string(from: Date())
            
            // Get current count from AppDelegate
            let currentCount = AppDelegate.instance.keystrokeCount
            
            // Update or add today's entry
            if let index = updatedHistoryData.firstIndex(where: { $0.date == today }) {
                updatedHistoryData[index] = (date: today, count: currentCount)
            } else {
                updatedHistoryData.append((date: today, count: currentCount))
                // Sort by date to ensure chronological order
                updatedHistoryData.sort(by: { $0.date < $1.date })
            }
            
            // Sort by date to ensure chronological order
            updatedHistoryData.sort(by: { $0.date < $1.date })
        
            // Don't limit the data - show all available history
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.historyData = updatedHistoryData
                self.topKeys = newTopKeys
                self.topShortcuts = newTopShortcuts
                self.lastUpdateTime = Date()
                self.isRefreshing = false
                
                // Call completion handler if provided
                completion?()
            }
        }
    }
    
    func forceRefresh(completion: (() -> Void)? = nil) {
        refreshData(completion: completion)
    }
}
