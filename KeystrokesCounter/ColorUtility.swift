import SwiftUI

struct ColorUtility {
    static func heatColor(percentage: Double) -> Color {
        let adjusted = min(1.0, max(0.0, percentage))
        
        if adjusted < 0.001 {
            return Color.gray.opacity(0.3) // Almost unused 
        } else if adjusted < 0.25 {
            return Color(red: 0.68, green: 0.85, blue: 0.9)  // Pastel blue for low usage
        } else if adjusted < 0.5 {
            return Color(red: 0.69, green: 0.9, blue: 0.69)  // Pastel green for medium-low usage
        } else if adjusted < 0.75 {
            return Color(red: 0.95, green: 0.95, blue: 0.7)  // Pastel yellow for medium-high usage
        } else {
            return Color(red: 0.95, green: 0.71, blue: 0.76)  // Pastel pink/red for high usage
        }
    }
    
    static func indexColor(index: Int) -> Color {
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
import SwiftUI

struct ColorUtility {
    static func heatColor(percentage: Double) -> Color {
        let adjusted = min(1.0, max(0.0, percentage))
        
        if adjusted < 0.001 {
            return Color.gray.opacity(0.3) // Almost unused 
        } else if adjusted < 0.25 {
            return Color(red: 0.68, green: 0.85, blue: 0.9)  // Pastel blue for low usage
        } else if adjusted < 0.5 {
            return Color(red: 0.69, green: 0.9, blue: 0.69)  // Pastel green for medium-low usage
        } else if adjusted < 0.75 {
            return Color(red: 0.95, green: 0.95, blue: 0.7)  // Pastel yellow for medium-high usage
        } else {
            return Color(red: 0.95, green: 0.71, blue: 0.76)  // Pastel pink/red for high usage
        }
    }
    
    static func indexColor(index: Int) -> Color {
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
