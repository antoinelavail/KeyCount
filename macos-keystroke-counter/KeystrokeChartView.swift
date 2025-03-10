import SwiftUI
import Charts

struct KeystrokeChartView: View {
    @State private var historyData: [(date: String, count: Int)] = []
    @State private var selectedDays: Int = 7
    
    var body: some View {
        VStack {
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
                .frame(height: 300)
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
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        historyData = KeystrokeHistoryManager.shared.getKeystrokeHistory(days: selectedDays)
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
