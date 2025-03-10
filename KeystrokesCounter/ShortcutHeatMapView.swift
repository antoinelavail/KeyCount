import SwiftUI

struct ShortcutHeatMapView: View {
    @ObservedObject private var keyTracker = KeyUsageTracker.shared
    @State private var topShortcuts: [(shortcut: KeyboardShortcut, count: Int, description: String)] = []
    @State private var maxCount: Int = 0
    @State private var selectedTimeRange: TimeRange = .today
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.title)
                .padding(.bottom, 4)
            
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
            
            // Top 10 shortcuts section
            VStack(alignment: .leading, spacing: 8) {
                Text("Most Used Shortcuts")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                if topShortcuts.isEmpty {
                    Text("No shortcut usage data available")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(0..<min(10, topShortcuts.count), id: \.self) { index in
                            ShortcutListItem(
                                index: index,
                                shortcut: topShortcuts[index],
                                totalShortcuts: getTotalShortcuts(),
                                timeRange: selectedTimeRange
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.03), value: selectedTimeRange)
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
            
            // Shortcut visualization section
            ScrollView {
                VStack(spacing: 16) {
                    Text("Shortcut Usage Visualization")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    // Visualization as horizontal bars
                    if !topShortcuts.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(0..<min(15, topShortcuts.count), id: \.self) { index in
                                ShortcutBarView(
                                    index: index,
                                    shortcut: topShortcuts[index],
                                    maxCount: maxCount
                                )
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.03), value: selectedTimeRange)
                                .id("\(selectedTimeRange)-viz-\(index)")
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            loadShortcutData()
        }
    }
    
    private func loadShortcutData() {
        topShortcuts = keyTracker.getTopShortcutsForTimeRange(count: 30, timeRange: selectedTimeRange)
        maxCount = topShortcuts.first?.count ?? 0
    }
    
    private func getTotalShortcuts() -> Int? {
        let total = topShortcuts.reduce(0) { $0 + $1.count }
        return total > 0 ? total : nil
    }
}

// Component for individual shortcut list items
struct ShortcutListItem: View {
    let index: Int
    let shortcut: (shortcut: KeyboardShortcut, count: Int, description: String)
    let totalShortcuts: Int?
    let timeRange: TimeRange
    
    var body: some View {
        HStack {
            Text("\(index + 1).")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
            
            Text(shortcut.description)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(minWidth: 100, alignment: .leading)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shortcutColor(for: index))
                )
            
            Text("\(shortcut.count) times")
                .font(.body)
            
            Spacer()
            
            // Percentage of total
            if let total = totalShortcuts {
                let percentage = Double(shortcut.count) / Double(total) * 100
                Text(String(format: "%.1f%%", percentage))
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id("\(timeRange)-\(index)")
    }
    
    private func shortcutColor(for index: Int) -> Color {
        return ColorUtility.indexColor(index: index)
    }
}

// Component for visualization bars
struct ShortcutBarView: View {
    let index: Int
    let shortcut: (shortcut: KeyboardShortcut, count: Int, description: String)
    let maxCount: Int
    
    var body: some View {
        HStack {
            Text(shortcut.description)
                .font(.system(.body, design: .monospaced))
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 24)
                        .opacity(0.1)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .frame(width: max(4, CGFloat(shortcut.count) / CGFloat(maxCount) * geometry.size.width), height: 24)
                        .foregroundColor(shortcutColor(for: index))
                        .cornerRadius(4)
                    
                    Text("\(shortcut.count)")
                        .font(.caption)
                        .padding(.leading, 8)
                        .foregroundColor(.white)
                }
            }
            .frame(height: 24)
        }
    }
    
    private func shortcutColor(for index: Int) -> Color {
        return ColorUtility.indexColor(index: index)
    }
}
