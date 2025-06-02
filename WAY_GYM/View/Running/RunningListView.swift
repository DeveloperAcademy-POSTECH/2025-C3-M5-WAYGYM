import SwiftUI

struct RunningListView: View {
    @State private var runRecords = RunRecordModel.dummyData
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(runRecords, id: \.id) { record in
                    let routeImageName = (record.routeImage ?? "route_1").replacingOccurrences(of: ".png", with: "")
                    let dateText = formatDate(record.startTime)
                    let distanceText = String(format: "%.2fkm", record.totalDistance / 1000)
                    
                    ZStack {
                        Color.white
                        
                        HStack {
                            Image(routeImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100)
                            
                            VStack(alignment: .leading) {
                                Text(dateText)
                                
                                HStack {
                                    Text(distanceText)
                                    Text("\(Int(record.duration / 60))min")
                                }
                                .bold()
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .frame(height: 150)
                }
            }
        }
    }
}

#Preview {
    RunningListView()
}
