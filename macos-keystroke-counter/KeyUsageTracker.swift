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
