import SwiftUI

struct KeyboardHeatMapView: View {
    @ObservedObject private var keyTracker = KeyUsageTracker.shared
    @State private var maxCount: Int = 0
    
    // Define keyboard layout rows
    private let keyboardRows: [[KeyInfo]] = [
        // Row 1: Function keys (unchanged)
        [
            KeyInfo(label: "esc", keyCode: 53, width: 1.3),
            KeyInfo(label: "F1", keyCode: 122, width: 1),
            KeyInfo(label: "F2", keyCode: 120, width: 1),
            KeyInfo(label: "F3", keyCode: 99, width: 1),
            KeyInfo(label: "F4", keyCode: 118, width: 1),
            KeyInfo(label: "F5", keyCode: 96, width: 1),
            KeyInfo(label: "F6", keyCode: 97, width: 1),
            KeyInfo(label: "F7", keyCode: 98, width: 1),
            KeyInfo(label: "F8", keyCode: 100, width: 1),
            KeyInfo(label: "F9", keyCode: 101, width: 1),
            KeyInfo(label: "F10", keyCode: 109, width: 1),
            KeyInfo(label: "F11", keyCode: 103, width: 1),
            KeyInfo(label: "F12", keyCode: 111, width: 1)
        ],
        // Row 2: Number row (AZERTY)
        [
            KeyInfo(label: "²", keyCode: 50, width: 1),
            KeyInfo(label: "&", keyCode: 18, width: 1),
            KeyInfo(label: "é", keyCode: 19, width: 1),
            KeyInfo(label: "\"", keyCode: 20, width: 1),
            KeyInfo(label: "'", keyCode: 21, width: 1),
            KeyInfo(label: "(", keyCode: 23, width: 1),
            KeyInfo(label: "§", keyCode: 22, width: 1),
            KeyInfo(label: "è", keyCode: 26, width: 1),
            KeyInfo(label: "!", keyCode: 28, width: 1),
            KeyInfo(label: "ç", keyCode: 25, width: 1),
            KeyInfo(label: "à", keyCode: 29, width: 1),
            KeyInfo(label: ")", keyCode: 27, width: 1),
            KeyInfo(label: "=", keyCode: 24, width: 1),
            KeyInfo(label: "⌫", keyCode: 51, width: 1.5)
        ],
        // Row 3: AZERTY top row
        [
            KeyInfo(label: "⇥", keyCode: 48, width: 1.5),
            KeyInfo(label: "A", keyCode: 12, width: 1),
            KeyInfo(label: "Z", keyCode: 13, width: 1),
            KeyInfo(label: "E", keyCode: 14, width: 1),
            KeyInfo(label: "R", keyCode: 15, width: 1),
            KeyInfo(label: "T", keyCode: 17, width: 1),
            KeyInfo(label: "Y", keyCode: 16, width: 1),
            KeyInfo(label: "U", keyCode: 32, width: 1),
            KeyInfo(label: "I", keyCode: 34, width: 1),
            KeyInfo(label: "O", keyCode: 31, width: 1),
            KeyInfo(label: "P", keyCode: 35, width: 1),
            KeyInfo(label: "^", keyCode: 33, width: 1),
            KeyInfo(label: "$", keyCode: 30, width: 1),
            KeyInfo(label: "⏎", keyCode: 36, width: 1.5)
        ],
        // Row 4: AZERTY home row
        [
            KeyInfo(label: "⇪", keyCode: 57, width: 1.75),
            KeyInfo(label: "Q", keyCode: 0, width: 1),
            KeyInfo(label: "S", keyCode: 1, width: 1),
            KeyInfo(label: "D", keyCode: 2, width: 1),
            KeyInfo(label: "F", keyCode: 3, width: 1),
            KeyInfo(label: "G", keyCode: 5, width: 1),
            KeyInfo(label: "H", keyCode: 4, width: 1),
            KeyInfo(label: "J", keyCode: 38, width: 1),
            KeyInfo(label: "K", keyCode: 40, width: 1),
            KeyInfo(label: "L", keyCode: 37, width: 1),
            KeyInfo(label: "M", keyCode: 41, width: 1),
            KeyInfo(label: "ù", keyCode: 39, width: 1),
            KeyInfo(label: "*", keyCode: 42, width: 1)
        ],
        // Row 5: AZERTY bottom row
        [
            KeyInfo(label: "⇧", keyCode: 56, width: 1.5),
            KeyInfo(label: "<", keyCode: 50, width: 1),
            KeyInfo(label: "W", keyCode: 6, width: 1),
            KeyInfo(label: "X", keyCode: 7, width: 1),
            KeyInfo(label: "C", keyCode: 8, width: 1),
            KeyInfo(label: "V", keyCode: 9, width: 1),
            KeyInfo(label: "B", keyCode: 11, width: 1),
            KeyInfo(label: "N", keyCode: 45, width: 1),
            KeyInfo(label: ",", keyCode: 43, width: 1),
            KeyInfo(label: ";", keyCode: 47, width: 1),
            KeyInfo(label: ":", keyCode: 44, width: 1),
            KeyInfo(label: "!", keyCode: 48, width: 1),
            KeyInfo(label: "⇧", keyCode: 56, width: 1.5)
        ],
        // Row 6: Spacebar row (mostly unchanged)
        [
            KeyInfo(label: "fn", keyCode: 63, width: 1.25),
            KeyInfo(label: "⌃", keyCode: 59, width: 1.25),
            KeyInfo(label: "⌥", keyCode: 58, width: 1.25),
            KeyInfo(label: "⌘", keyCode: 55, width: 1.25),
            KeyInfo(label: "", keyCode: 49, width: 5), // Spacebar
            KeyInfo(label: "⌘", keyCode: 55, width: 1.25),
            KeyInfo(label: "⌥", keyCode: 58, width: 1.25),
            KeyInfo(label: "◀", keyCode: 123, width: 1),
            KeyInfo(label: "▲", keyCode: 126, width: 1),
            KeyInfo(label: "▼", keyCode: 125, width: 1),
            KeyInfo(label: "▶", keyCode: 124, width: 1)
        ]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Keyboard layout visualization
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 4) {
                    ForEach(keyboardRows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 4) {
                            ForEach(keyboardRows[rowIndex].indices, id: \.self) { keyIndex in
                                let keyInfo = keyboardRows[rowIndex][keyIndex]
                                KeyView(
                                    keyInfo: keyInfo,
                                    usageCount: keyTracker.getCombinedKeyCount(for: keyInfo.keyCode),
                                    maxCount: maxCount
                                )
                            }
                        }
                    }
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
            .frame(height: 250)
            
            // Color scale legend
            VStack(spacing: 12) {
                Text("Keystroke Color Scale")
                    .font(.headline)
                    .padding(.top, 4)
                
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading) {
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .cornerRadius(4)
                            
                            Text("Unused")
                                .font(.caption)
                        }
                        
                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.68, green: 0.85, blue: 0.9))
                                .frame(width: 20, height: 20)
                                .cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text("Light Usage")
                                    .font(.caption)
                                Text("1-\(Int(Double(maxCount) * 0.25)) keystrokes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.69, green: 0.9, blue: 0.69))
                                .frame(width: 20, height: 20)
                                .cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text("Medium-Light Usage")
                                    .font(.caption)
                                Text("\(Int(Double(maxCount) * 0.25) + 1)-\(Int(Double(maxCount) * 0.5)) keystrokes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.95, green: 0.95, blue: 0.7))
                                .frame(width: 20, height: 20)
                                .cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text("Medium-Heavy Usage")
                                    .font(.caption)
                                Text("\(Int(Double(maxCount) * 0.5) + 1)-\(Int(Double(maxCount) * 0.75)) keystrokes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.95, green: 0.71, blue: 0.76))
                                .frame(width: 20, height: 20)
                                .cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text("Heavy Usage")
                                    .font(.caption)
                                Text("\(Int(Double(maxCount) * 0.75) + 1)-\(maxCount) keystrokes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .padding(.top, 8)
        }
        .onAppear {
            // Calculate max count considering both direct keypresses and shortcuts
            updateMaxCount()
        }
    }
    
    private func heatGradient(percentage: Double) -> Color {
        let adjusted = min(1.0, max(0.0, percentage))
        if adjusted < 0.25 {
            return Color(red: 0.68, green: 0.85, blue: 0.9)  // Pastel blue
        } else if adjusted < 0.5 {
            return Color(red: 0.69, green: 0.9, blue: 0.69)  // Pastel green
        } else if adjusted < 0.75 {
            return Color(red: 0.95, green: 0.95, blue: 0.7)  // Pastel yellow
        } else {
            return Color(red: 0.95, green: 0.71, blue: 0.76)  // Pastel pink/red
        }
    }
    
    private func updateMaxCount() {
        // Get max from combined counts across all keys
        var combinedMaxCount = 0
        for row in keyboardRows {
            for keyInfo in row {
                let combinedCount = keyTracker.getCombinedKeyCount(for: keyInfo.keyCode)
                if combinedCount > combinedMaxCount {
                    combinedMaxCount = combinedCount
                }
            }
        }
        
        maxCount = combinedMaxCount > 0 ? combinedMaxCount : 1
    }
}

// Top Keys View
struct TopKeysView: View {
    @ObservedObject private var keyTracker = KeyUsageTracker.shared
    @State private var topKeys: [(keyCode: UInt16, count: Int, label: String)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Used Keys")
                .font(.title2)
                .padding(.horizontal)
            
            if topKeys.isEmpty {
                Text("No key usage data available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(0..<min(10, topKeys.count), id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            
                            Text(topKeys[index].label)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(keyColor(for: index))
                                )
                            
                            Text("\(topKeys[index].count) keystrokes")
                                .font(.body)
                            
                            Spacer()
                            
                            // Percentage of total
                            if let totalKeystrokes = getTotalKeystrokes() {
                                let percentage = Double(topKeys[index].count) / Double(totalKeystrokes) * 100
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
            loadTopKeys()
        }
    }
    
    private func loadTopKeys() {
        topKeys = keyTracker.getTopKeys(count: 10)
    }
    
    private func getTotalKeystrokes() -> Int? {
        let total = topKeys.reduce(0) { $0 + $1.count }
        return total > 0 ? total : nil
    }
    
    private func keyColor(for index: Int) -> Color {
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

struct KeyInfo {
    let label: String
    let keyCode: UInt16
    let width: CGFloat
}

struct KeyView: View {
    let keyInfo: KeyInfo
    let usageCount: Int
    let maxCount: Int
    
    // Adjust the base size to be slightly smaller for better fit
    private let baseWidth: CGFloat = 30
    private let baseHeight: CGFloat = 30
    
    var body: some View {
        Text(keyInfo.label)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .frame(width: baseWidth * keyInfo.width, height: baseHeight)
            .background(heatColor)
            .cornerRadius(5)
    }
    
    private var heatColor: Color {
        if maxCount == 0 {
            return Color.gray.opacity(0.3)
        }
        
        let percentage = Double(usageCount) / Double(maxCount)
        
        if percentage < 0.001 {
            return Color.gray.opacity(0.3) // Almost unused keys
        } else if percentage < 0.25 {
            return Color(red: 0.68, green: 0.85, blue: 0.9)  // Pastel blue for low usage
        } else if percentage < 0.5 {
            return Color(red: 0.69, green: 0.9, blue: 0.69)  // Pastel green for medium-low usage
        } else if percentage < 0.75 {
            return Color(red: 0.95, green: 0.95, blue: 0.7)  // Pastel yellow for medium-high usage
        } else {
            return Color(red: 0.95, green: 0.71, blue: 0.76)  // Pastel pink/red for high usage
        }
    }
}
