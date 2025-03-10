import SwiftUI
import Charts

struct KeystrokeChartView: View {
    @State private var historyData: [(date: String, count: Int)] = []
    @State private var selectedDays: Int = 7
    var highlightToday: Bool = false {
        didSet {
            if oldValue != highlightToday {
                loadData()
            }
        }
    }
    var todayCount: Int = 0 {
        didSet {
            if oldValue != todayCount {
                loadData()
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Today's keystrokes section
                TodayKeystrokesView(todayCount: todayCount)
                
                // 2. Most used keys section
                TopKeysView()
                    .padding(.horizontal)
                
                // 3. Most used shortcuts section
                TopShortcutsView()
                    .padding(.horizontal)
                
                // 4. Keys heatmap (combined keys and shortcuts)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Heat Map")
                        .font(.title2)
                        .padding(.horizontal)
                    
                    KeyboardHeatMapView()
                        .padding(.horizontal)
                }
                
                // 5. History chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("History")
                        .font(.title2)
                        .padding(.horizontal)
                    
                    Picker("Time Period", selection: $selectedDays) {
                        Text("7 Days").tag(7)
                        Text("14 Days").tag(14)
                        Text("30 Days").tag(30)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedDays) { _ in
                        loadData()
                    }
                    
                    if historyData.isEmpty {
                        Text("No history data available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        // Chart in a rounded blurred container
                        VStack {
                            Chart {
                                ForEach(historyData, id: \.date) { item in
                                    BarMark(
                                        x: .value("Date", formatDate(item.date)),
                                        y: .value("Keystrokes", item.count)
                                    )
                                    .foregroundStyle(Color.blue.gradient)
                                }
                            }
                            .frame(height: 250)
                            .padding()
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                
                // Quit Button
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    Text("Quit")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 600, maxWidth: .infinity)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        // Get history data
        var data = KeystrokeHistoryManager.shared.getKeystrokeHistory(days: selectedDays)
        
        if highlightToday {
            // Format today's date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let today = dateFormatter.string(from: Date())
            
            // Check if today is already in the data
            let containsToday = data.contains(where: { $0.date == today })
            
            // If not, or if we need to update it, add/update today's count
            if !containsToday {
                data.append((date: today, count: todayCount))
            } else if let index = data.firstIndex(where: { $0.date == today }) {
                // Update today's count in the existing data
                data[index] = (date: today, count: todayCount)
            }
            
            // Sort data by date
            data.sort(by: { $0.date < $1.date })
        }
        
        historyData = data
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

// Today's Keystrokes View
struct TodayKeystrokesView: View {
    var todayCount: Int
    
    var body: some View {
        VStack(spacing: 5) {
            Text("Today's Keystrokes")
                .font(.title)
            
            Text("\(todayCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// Top Shortcuts View (extracted from ShortcutHeatMapView)
struct TopShortcutsView: View {
    @ObservedObject private var keyTracker = KeyUsageTracker.shared
    @State private var topShortcuts: [(shortcut: KeyboardShortcut, count: Int, description: String)] = []
    @State private var maxCount: Int = 0
    @State private var selectedTimeRange: TimeRange = .today
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Used Shortcuts")
                .font(.title2)
                .padding(.horizontal)
            
            // Time range selector
            Picker("Time Range", selection: $selectedTimeRange) {
                Text(TimeRange.today.description).tag(TimeRange.today)
                Text(TimeRange.lastWeek.description).tag(TimeRange.lastWeek)
                Text(TimeRange.lastMonth.description).tag(TimeRange.lastMonth)
                Text(TimeRange.allTime.description).tag(TimeRange.allTime)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedTimeRange) { _ in
                loadShortcutData()
            }
            
            if topShortcuts.isEmpty {
                Text("No shortcut usage data available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(0..<min(10, topShortcuts.count), id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            
                            Text(topShortcuts[index].description)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                                .frame(minWidth: 100, alignment: .leading)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(shortcutColor(for: index))
                                )
                            
                            Text("\(topShortcuts[index].count) times")
                                .font(.body)
                            
                            Spacer()
                            
                            // Percentage of total
                            if let totalShortcuts = getTotalShortcuts() {
                                let percentage = Double(topShortcuts[index].count) / Double(totalShortcuts) * 100
                                Text(String(format: "%.1f%%", percentage))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .onAppear {
            loadShortcutData()
        }
    }
    
    private func loadShortcutData() {
        topShortcuts = keyTracker.getTopShortcutsForTimeRange(count: 10, timeRange: selectedTimeRange)
        maxCount = topShortcuts.first?.count ?? 0
    }
    
    private func getTotalShortcuts() -> Int? {
        let total = topShortcuts.reduce(0) { $0 + $1.count }
        return total > 0 ? total : nil
    }
    
    private func shortcutColor(for index: Int) -> Color {
        return ColorUtility.indexColor(index: index)
    }
}

