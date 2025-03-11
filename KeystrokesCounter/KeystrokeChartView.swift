import SwiftUI
import Charts

struct KeystrokeChartView: View {
    @EnvironmentObject private var animationManager: WindowAnimationManager
    @ObservedObject private var dataStore = StatsDataStore.shared
    var highlightToday: Bool = false
    var todayCount: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Today's keystrokes section with simplified animation
                TodayKeystrokesView()
                    .slideInAnimation(index: 0)
                
                // 2. Most used keys section
                TopKeysView()
                    .padding(.horizontal)
                    .slideInAnimation(index: 1)
                
                // 3. Most used shortcuts section
                TopShortcutsView()
                    .padding(.horizontal)
                    .slideInAnimation(index: 2)
                
                // 4. Keys heatmap (combined keys and shortcuts)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Heat Map")
                        .font(.title2)
                        .padding(.horizontal)
                    
                    KeyboardHeatMapView()
                        .padding(.horizontal)
                }
                .slideInAnimation(index: 3)
                
                // 5. History chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("History")
                        .font(.title2)
                        .padding(.horizontal)
                    
                    Picker("Time Period", selection: $dataStore.selectedDays) {
                        Text("7 Days").tag(7)
                        Text("14 Days").tag(14)
                        Text("30 Days").tag(30)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: dataStore.selectedDays) { _ in
                        dataStore.forceRefresh()
                    }
                    
                    if dataStore.historyData.isEmpty {
                        Text("No history data available")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        // Chart in a rounded blurred container
                        VStack {
                            Chart {
                                ForEach(dataStore.historyData, id: \.date) { item in
                                    BarMark(
                                        x: .value("Date", formatDate(item.date)),
                                        y: .value("Keystrokes", item.count)
                                    )
                                    .foregroundStyle(
                                        isToday(item.date) ? 
                                            Color.blue.gradient : 
                                            Color.green.opacity(0.7).gradient
                                    )
                                    .annotation(position: .top) {
                                        if item.count > 0 {
                                            Text("\(item.count)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .chartYScale(domain: 0...(Double(maxKeystrokeCount()) * 1.1))
                            .frame(height: 250)
                            .padding()
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                .slideInAnimation(index: 4)
                
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
                .slideInAnimation(index: 5, baseDelay: 0.1)
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Inject test data (temporary for testing)
            KeystrokeHistoryManager.shared.injectTestData()
            
            dataStore.forceRefresh()
            KeystrokeHistoryManager.shared.printAllHistoryKeys()
        }
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
    
    private func isToday(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return dateString == today
    }
    
    private func maxKeystrokeCount() -> Int {
        let max = dataStore.historyData.map { $0.count }.max() ?? 1000
        return max > 0 ? max : 1000
    }
}

// Today's Keystrokes View
struct TodayKeystrokesView: View {
    // Use @State to track the keystroke count and force refreshes
    @State private var keystrokeCount = AppDelegate.instance.keystrokeCount
    
    var body: some View {
        VStack(spacing: 5) {
            Text("Today's Keystrokes")
                .font(.title)
            
            // Display the current count from AppDelegate directly
            Text("\(AppDelegate.instance.keystrokeCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .id("keystroke-\(AppDelegate.instance.keystrokeCount)") // Force refresh when count changes
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding(.horizontal)
        .onAppear {
            // Update local state on appear
            keystrokeCount = AppDelegate.instance.keystrokeCount
        }
    }
}

// Top Shortcuts View (extracted from ShortcutHeatMapView)
struct TopShortcutsView: View {
    @ObservedObject private var dataStore = StatsDataStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Used Shortcuts")
                .font(.title2)
                .padding(.horizontal)
            
            // Time range selector
            Picker("Time Range", selection: $dataStore.selectedShortcutsTimeRange) {
                Text(TimeRange.today.description).tag(TimeRange.today)
                Text(TimeRange.lastWeek.description).tag(TimeRange.lastWeek)
                Text(TimeRange.lastMonth.description).tag(TimeRange.lastMonth)
                Text(TimeRange.allTime.description).tag(TimeRange.allTime)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: dataStore.selectedShortcutsTimeRange) { _ in
                dataStore.forceRefresh()
            }
            
            if dataStore.topShortcuts.isEmpty {
                Text("No shortcut usage data available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(0..<min(10, dataStore.topShortcuts.count), id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            
                            Text(dataStore.topShortcuts[index].description)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                                .frame(minWidth: 100, alignment: .leading)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(shortcutColor(for: index))
                                )
                            
                            Text("\(dataStore.topShortcuts[index].count) times")
                                .font(.body)
                            
                            Spacer()
                            
                            // Percentage of total
                            if let totalShortcuts = getTotalShortcuts() {
                                let percentage = Double(dataStore.topShortcuts[index].count) / Double(totalShortcuts) * 100
                                Text(String(format: "%.1f%%", percentage))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .transition(.move(edge: .leading)) // Simplified transition
                        .animation(.easeOut(duration: 0.15).delay(Double(index) * 0.02), value: dataStore.selectedShortcutsTimeRange)
                        .id("\(dataStore.selectedShortcutsTimeRange)-\(index)") // Important for SwiftUI to detect changes
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
            dataStore.forceRefresh()
        }
    }
    
    private func getTotalShortcuts() -> Int? {
        let total = dataStore.topShortcuts.reduce(0) { $0 + $1.count }
        return total > 0 ? total : nil
    }
    
    private func shortcutColor(for index: Int) -> Color {
        return ColorUtility.indexColor(index: index)
    }
}

