import SwiftUI

struct ProfileRunningView: View {
    var body: some View {
        let latestRuns = RunRecordModel.dummyData.suffix(3)
        
        ScrollView {
            VStack(spacing: 16) {
                ForEach(latestRuns, id: \.id) { record in
                    
                    let dateText = formatDate(record.startTime)
                    let distanceText = String(format: "%.2fkm", record.totalDistance / 1000)
                    let durationMin = record.endTime != nil ? Int(record.endTime!.timeIntervalSince(record.startTime) / 60) : 0

                    ZStack {
                        Color.white
                        HStack {
                            Image(record.routeImage?.replacingOccurrences(of: ".png", with: "") ?? "route_1")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100)

                            VStack(alignment: .leading) {
                                Text(dateText)
                                HStack {
                                    Text(distanceText)
                                    Text("\(durationMin)min")
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

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

#Preview {
    ProfileRunningView()
}
