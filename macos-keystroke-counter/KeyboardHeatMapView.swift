import SwiftUI

struct KeyboardHeatMapView: View {
    @ObservedObject private var keyTracker = KeyUsageTracker.shared
    @State private var maxCount: Int = 0
    
    // Define keyboard layout rows
    private let keyboardRows: [[KeyInfo]] = [
        // Row 1: Function keys
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
        // Row 2: Number row
        [
            KeyInfo(label: "`", keyCode: 50, width: 1),
            KeyInfo(label: "1", keyCode: 18, width: 1),
            KeyInfo(label: "2", keyCode: 19, width: 1),
            KeyInfo(label: "3", keyCode: 20, width: 1),
            KeyInfo(label: "4", keyCode: 21, width: 1),
            KeyInfo(label: "5", keyCode: 23, width: 1),
            KeyInfo(label: "6", keyCode: 22, width: 1),
            KeyInfo(label: "7", keyCode: 26, width: 1),
            KeyInfo(label: "8", keyCode: 28, width: 1),
            KeyInfo(label: "9", keyCode: 25, width: 1),
            KeyInfo(label: "0", keyCode: 29, width: 1),
            KeyInfo(label: "-", keyCode: 27, width: 1),
            KeyInfo(label: "=", keyCode: 24, width: 1),
            KeyInfo(label: "⌫", keyCode: 51, width: 1.5)
        ],
        // Row 3: QWERTY row
        [
            KeyInfo(label: "⇥", keyCode: 48, width: 1.5),
            KeyInfo(label: "Q", keyCode: 12, width: 1),
            KeyInfo(label: "W", keyCode: 13, width: 1),
            KeyInfo(label: "E", keyCode: 14, width: 1),
            KeyInfo(label: "R", keyCode: 15, width: 1),
            KeyInfo(label: "T", keyCode: 17, width: 1),
            KeyInfo(label: "Y", keyCode: 16, width: 1),
            KeyInfo(label: "U", keyCode: 32, width: 1),
            KeyInfo(label: "I", keyCode: 34, width: 1),
            KeyInfo(label: "O", keyCode: 31, width: 1),
            KeyInfo(label: "P", keyCode: 35, width: 1),
            KeyInfo(label: "[", keyCode: 33, width: 1),
            KeyInfo(label: "]", keyCode: 30, width: 1),
            KeyInfo(label: "\\", keyCode: 42, width: 1)
        ],
        // Row 4: Home row
        [
            KeyInfo(label: "⇪", keyCode: 57, width: 1.75),
            KeyInfo(label: "A", keyCode: 0, width: 1),
            KeyInfo(label: "S", keyCode: 1, width: 1),
            KeyInfo(label: "D", keyCode: 2, width: 1),
            KeyInfo(label: "F", keyCode: 3, width: 1),
            KeyInfo(label: "G", keyCode: 5, width: 1),
            KeyInfo(label: "H", keyCode: 4, width: 1),
            KeyInfo(label: "J", keyCode: 38, width: 1),
            KeyInfo(label: "K", keyCode: 40, width: 1),
            KeyInfo(label: "L", keyCode: 37, width: 1),
            KeyInfo(label: ";", keyCode: 41, width: 1),
            KeyInfo(label: "'", keyCode: 39, width: 1),
            KeyInfo(label: "⏎", keyCode: 36, width: 1.75)
        ],
        // Row 5: Bottom row
        [
            KeyInfo(label: "⇧", keyCode: 56, width: 2.25),
            KeyInfo(label: "Z", keyCode: 6, width: 1),
            KeyInfo(label: "X", keyCode: 7, width: 1),
            KeyInfo(label: "C", keyCode: 8, width: 1),
            KeyInfo(label: "V", keyCode: 9, width: 1),
            KeyInfo(label: "B", keyCode: 11, width: 1),
            KeyInfo(label: "N", keyCode: 45, width: 1),
            KeyInfo(label: "M", keyCode: 46, width: 1),
            KeyInfo(label: ",", keyCode: 43, width: 1),
            KeyInfo(label: ".", keyCode: 47, width: 1),
            KeyInfo(label: "/", keyCode: 44, width: 1),
            KeyInfo(label: "⇧", keyCode: 56, width: 2.25)
        ],
        // Row 6: Spacebar row
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
        VStack(spacing: 6) {
            Text("Keyboard Heat Map")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Add a ScrollView to ensure the keyboard is always accessible
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 4) {
                    ForEach(keyboardRows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 4) {
                            ForEach(keyboardRows[rowIndex].indices, id: \.self) { keyIndex in
                                let keyInfo = keyboardRows[rowIndex][keyIndex]
                                KeyView(
                                    keyInfo: keyInfo,
                                    usageCount: keyTracker.getKeyCount(for: keyInfo.keyCode),
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
            // Set minimum height for the scroll area
            .frame(minHeight: 300)
            
            HStack(spacing: 0) {
                ForEach(0..<5) { i in
                    Rectangle()
                        .fill(heatGradient(percentage: Double(i) / 4))
                        .frame(height: 10)
                    
                    if i < 4 {
                        Spacer()
                    }
                }
            }
            .frame(height: 10)
            .padding(.horizontal)
            
            HStack {
                Text("Least Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Most Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity) // Allow view to use all available width
        .padding()
        .onAppear {
            // Get max count when view appears
            maxCount = keyTracker.getMaxCount()
        }
    }
    
    private func heatGradient(percentage: Double) -> Color {
        let adjusted = min(1.0, max(0.0, percentage))
        if adjusted < 0.25 {
            return Color(red: 0, green: 0, blue: 1.0)  // Blue
        } else if adjusted < 0.5 {
            return Color(red: 0, green: 1.0, blue: 1.0)  // Cyan
        } else if adjusted < 0.75 {
            return Color(red: 1.0, green: 1.0, blue: 0)  // Yellow
        } else {
            return Color(red: 1.0, green: 0, blue: 0)  // Red
        }
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
            return Color(red: 0, green: 0, blue: 1.0)  // Blue for low usage
        } else if percentage < 0.5 {
            return Color(red: 0, green: 1.0, blue: 1.0)  // Cyan for medium-low usage
        } else if percentage < 0.75 {
            return Color(red: 1.0, green: 1.0, blue: 0)  // Yellow for medium-high usage
        } else {
            return Color(red: 1.0, green: 0, blue: 0)  // Red for high usage
        }
    }
}
