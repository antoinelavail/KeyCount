import SwiftUI
import Charts

struct KeystrokeChartView: View {
    @State private var historyData: [(date: String, count: Int)] = []
    @State private var selectedDays: Int = 7
    @State private var selectedTab = 0
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
        VStack(spacing: 16) {
            // Add top padding to prevent cut-off
            Spacer().frame(height: 12)
            
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
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .padding([.horizontal, .top])
            }
            
            Picker("View", selection: $selectedTab) {
                Text("History").tag(0)
                Text("Heat Map").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if selectedTab == 0 {
                Text("History")
                    .font(.title)
                    .padding(.top, 4)
                
                Picker("Time Period", selection: $selectedDays) {
                    Text("7 Days").tag(7)
                    Text("14 Days").tag(14)
                    Text("30 Days").tag(30)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedDays) { _ in
                    loadData()
                }
                
                if historyData.isEmpty {
                    Text("No history data available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Chart in a rounded blurred container
                    VStack {
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
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            } else {
                // Heat Map tab
                KeyboardHeatMapView()
                    .padding(.horizontal)
            }
            
            // Add spacer to push content up
            Spacer(minLength: 12)
            
            // Improved Quit button styling
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
            .padding(.top, 8)
            .padding(.bottom, 24) // Increased bottom padding
        }
        .frame(minWidth: 360, idealWidth: 700, maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 16) // Increased bottom padding
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
