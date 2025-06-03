import SwiftUI

struct ProfileRunningView: View {
    var body: some View {
        //:: 서버에서 최근 3개 기록 가져오도록 코드 수정
        let latestRuns = RunRecordModel.dummyData.suffix(3)
        
        ZStack {
            Color("gang_bg_profile")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    if latestRuns.isEmpty {
                        VStack(alignment: .center) {
                            Text("이런...!\n내 구역이 없잖아?!")
                            Text("\n구역확장을 해야겠어...!")
                        }
                        .padding(5)
                        .font(.text01)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        
                    } else {
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
