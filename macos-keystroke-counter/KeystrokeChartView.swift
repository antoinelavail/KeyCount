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
        VStack {
            // Today's count highlight section
            if highlightToday {
                VStack(spacing: 5) {
                    Text("Today's Keystrokes")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(todayCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .padding([.horizontal, .top])
            }
            
            Text("Keystroke History")
                .font(.title)
                .padding(.top)
            
            Picker("Time Period", selection: $selectedDays) {
                Text("7 Days").tag(7)
                Text("14 Days").tag(14)
                Text("30 Days").tag(30)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedDays) { _ in
                loadData()
            }
            
            if historyData.isEmpty {
                Text("No history data available")
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            } else {
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
                
                List {
                    ForEach(historyData, id: \.date) { item in
                        HStack {
                            Text(formatDate(item.date))
                            Spacer()
                            Text("\(item.count) keystrokes")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Add Quit button
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
        .frame(width: 360)
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

struct KeystrokeChartView_Previews: PreviewProvider {
    static var previews: some View {
        KeystrokeChartView()
    }
}
