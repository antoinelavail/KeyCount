import SwiftUI
import Combine

class RefreshTimer: ObservableObject {
    @Published var tick: Int = 0
    private var timer: Timer?
    
    func start() {
        // Update every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick += 1
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        timer?.invalidate()
    }
}

class StatsDataStore: ObservableObject {
    static let shared = StatsDataStore()
    
    // Published properties for UI components
    @Published var historyData: [(date: String, count: Int)] = []
    @Published var topKeys: [(keyCode: UInt16, count: Int, label: String)] = []
    @Published var topShortcuts: [(shortcut: KeyboardShortcut, count: Int, description: String)] = []
    @Published var lastUpdateTime = Date()
    
    // Days selection for history
    @Published var selectedDays: Int = 7
    @Published var selectedKeysTimeRange: TimeRange = .today
    @Published var selectedShortcutsTimeRange: TimeRange = .today
    
    private var timer: Timer?
    private var isRefreshing = false
    
    private init() {
        // Start a background refresh timer with a reasonable interval
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshDataIfNeeded()
        }
    }
    
    func refreshDataIfNeeded() {
        // Avoid overlapping refreshes
        if isRefreshing { return }
        isRefreshing = true
        
        // Perform refresh on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
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
                updatedHistoryData.sort(by: { $0.date < $1.date })
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.historyData = updatedHistoryData
                self.topKeys = newTopKeys
                self.topShortcuts = newTopShortcuts
                self.lastUpdateTime = Date()
                self.isRefreshing = false
            }
        }
    }
    
    func forceRefresh() {
        refreshDataIfNeeded()
    }
    
    deinit {
        timer?.invalidate()
    }
}
