import Foundation

class KeyUsageTracker: ObservableObject {
    static let shared = KeyUsageTracker()
    
    @Published private var keyUsageCounts: [UInt16: Int] = [:]
    private let userDefaultsKey = "keyUsageCounts"
    
    init() {
        loadData()
    }
    
    func recordKeyPress(keyCode: UInt16) {
        keyUsageCounts[keyCode, default: 0] += 1
        saveData()
    }
    
    func getKeyCount(for keyCode: UInt16) -> Int {
        return keyUsageCounts[keyCode] ?? 0
    }
    
    func getMaxCount() -> Int {
        return keyUsageCounts.values.max() ?? 0
    }
    
    func getTopKeys(count: Int) -> [(keyCode: UInt16, count: Int, label: String)] {
        // Get keys sorted by usage (most used first)
        let sortedKeys = keyUsageCounts.sorted { $0.value > $1.value }
        
        // Take the top N keys
        let topKeys = sortedKeys.prefix(count)
        
        // Map to return array with key labels
        return topKeys.map { (keyCode: $0.key, count: $0.value, label: keyCodeToString($0.key)) }
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        // For AZERTY keyboard
        switch keyCode {
        case 0: return "Q"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "W"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "A"
        case 13: return "Z"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "&"
        case 19: return "é"
        case 20: return "\""
        case 21: return "'"
        case 22: return "§"
        case 23: return "("
        case 24: return "="
        case 25: return "ç"
        case 26: return "è"
        case 27: return ")"
        case 28: return "!"
        case 29: return "à"
        case 30: return "$"
        case 31: return "O"
        case 32: return "U"
        case 33: return "^"
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "ù"
        case 40: return "K"
        case 41: return "M"
        case 42: return "*"
        case 43: return ","
        case 44: return ":"
        case 45: return "N"
        case 46: return "M"
        case 47: return ";"
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 55: return "Command"
        case 56: return "Shift"
        case 57: return "Caps Lock"
        case 58: return "Option"
        case 59: return "Control"
        case 63: return "Fn"
        case 96...111: return "F\(keyCode - 95)"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default: return "Key \(keyCode)"
        }
    }
    
    func saveData() {
        if let encodedData = try? JSONEncoder().encode(keyUsageCounts) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
    
    func loadData() {
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedCounts = try? JSONDecoder().decode([UInt16: Int].self, from: savedData) {
            keyUsageCounts = decodedCounts
        }
    }
}
