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
                                .transition(.slide.combined(with: .opacity))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.03), value: selectedTimeRange)
                                .id("\(selectedTimeRange)-\(index)") // Important for transitions
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
                                HStack {
                                    Text(topShortcuts[index].description)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 100, alignment: .leading)
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .frame(width: geometry.size.width, height: 24)
                                                .opacity(0.1)
                                                .cornerRadius(4)
                                            
                                            Rectangle()
                                                .frame(width: max(4, CGFloat(topShortcuts[index].count) / CGFloat(maxCount) * geometry.size.width), height: 24)
                                                .foregroundColor(shortcutColor(for: index))
                                                .cornerRadius(4)
                                            
                                            Text("\(topShortcuts[index].count)")
                                                .font(.caption)
                                                .padding(.leading, 8)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(height: 24)
                                }
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
    
    private func shortcutColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.95, green: 0.71, blue: 0.76),  // 1st - Pastel pink/red
            Color(red: 0.95, green: 0.78, blue: 0.66),  // 2nd - Pastel orange
            Color(red: 0.95, green: 0.95, blue: 0.7),   // 3rd - Pastel yellow
            Color(red: 0.69, green: 0.9, blue: 0.69),   // 4th - Pastel green
            Color(red: 0.68, green: 0.85, blue: 0.9),   // 5th - Pastel blue
            Color(red: 0.8, green: 0.7, blue: 0.9),     // 6th - Pastel purple
            Color(red: 0.9, green: 0.7, blue: 0.85),    // 7th - Pastel magenta
            Color(red: 0.75, green: 0.88, blue: 0.8),   // 8th - Pastel teal
            Color(red: 0.85, green: 0.8, blue: 0.75),   // 9th - Pastel brown
            Color(red: 0.8, green: 0.8, blue: 0.8)      // 10th - Pastel gray
        ]
        
        return index < colors.count ? colors[index] : Color.gray.opacity(0.3)
    }
}
