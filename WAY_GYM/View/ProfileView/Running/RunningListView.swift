import SwiftUI

struct RunningListView: View {
    @State private var summaries: [RunSummary] = []
    @EnvironmentObject private var runRecordVM: RunRecordViewModel
    
    private var groupedSummaries: [String: [RunSummary]] {
        Dictionary(grouping: summaries) { summary in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy년 M월"
            formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            return formatter.string(from: summary.startTime)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gang_bg_primary_5
                    .ignoresSafeArea()
                
                VStack {
                    CustomNavigationBar(title: "구역 순찰 기록")
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 13) {
                            if summaries.isEmpty {
                                Text("데이터를 불러오는 중입니다...")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(groupedSummaries.keys.sorted(by: >), id: \.self) { month in
                                    let monthSummaries = groupedSummaries[month]!
                                    let totalArea = monthSummaries.reduce(0) { $0 + $1.capturedArea }
                                    let totalDistance = monthSummaries.reduce(0) { $0 + $1.distance }
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("\(month)")
                                            .font(.title02)
                                        HStack {
                                            Text("구역순찰 \(monthSummaries.count)회")
                                            Text("\(Int(totalArea))m²")
                                            Text("\(String(format: "%.2f", totalDistance / 1000))km")
                                        }
                                    }
                                    .font(.text02)
                                    .foregroundColor(.gang_text_1)
                                    .padding(.leading, 5)
                                    
                                    ForEach(monthSummaries) { summary in
                                        NavigationLink(destination: BigSingleRunningView(summary: summary)
                                            .foregroundColor(Color.gang_text_2)
                                            .font(.title01)
                                        ) {
                                            VStack(alignment: .center, spacing: 16) {
                                                HStack {
                                                    if let url = summary.routeImageURL {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .empty:
                                                                Text("준비중")
                                                                    .font(.text01)
                                                                    .frame(width: 96, height: 96)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                                                    .overlay(
                                                                        RoundedRectangle(cornerRadius: 16)
                                                                            .stroke(Color.gray, lineWidth: 1)
                                                                    )
                                                                    .padding(.trailing, 16)
                                                                
                                                            case .success(let image):
                                                                image
                                                                    .resizable()
                                                                    .frame(width: 96, height: 96)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                                                    .overlay(
                                                                        RoundedRectangle(cornerRadius: 16)
                                                                            .stroke(Color.gray, lineWidth: 1)
                                                                    )
                                                                    .padding(.trailing, 16)
                                                                
                                                            case .failure:
                                                                Text("준비중")
                                                                    .font(.text01)
                                                                    .frame(width: 96, height: 96)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                                                    .overlay(
                                                                        RoundedRectangle(cornerRadius: 16)
                                                                            .stroke(Color.gray, lineWidth: 1)
                                                                    )
                                                                    .padding(.trailing, 16)
                                                                
                                                                
                                                            @unknown default:
                                                                EmptyView()
                                                            }
                                                        }
                                                    } else {
                                                        Text("준비중")
                                                            .font(.text01)
                                                            .frame(width: 96, height: 96)
                                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 16)
                                                                    .stroke(Color.gray, lineWidth: 1)
                                                            )
                                                            .padding(.trailing, 16)
                                                    }

                                                    Text("\(Int(summary.capturedArea))m²")

                                                    Spacer()
                                                }

                                                HStack(spacing: 30) {
                                                    InfoItem(
                                                        title: "소요시간",
                                                        content: "\(Int(summary.duration) / 60):\(String(format: "%02d", Int(summary.duration) % 60))"
                                                    )
                                                    InfoItem(
                                                        title: "거리",
                                                        content: "\(String(format: "%.2f", summary.distance / 1000))km"
                                                    )
                                                    InfoItem(
                                                        title: "칼로리",
                                                        content: "\(Int(summary.calories))kcal"
                                                    )
                                                }
                                            }
                                            .foregroundColor(.text_primary)
                                            .padding(20)
                                            .frame(maxWidth: .infinity, alignment: .top)
                                            .background(Color.white)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .inset(by: 1)
                                                    .stroke(Color.gang_bg_secondary_2, lineWidth: 2)
                                            )
                                            .overlay(
                                                Text(summary.startTime.formattedDate())
                                                    .font(.text01)
                                                    .foregroundColor(.text_secondary)
                                                    .padding(20),
                                                alignment: .topTrailing
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                        }
                                       
                                    }
                                    
                                    Spacer()
                                        .frame(height: 4)
                                    
                                }
                                
                            }
                        }
                        .padding(.horizontal, 24)
                        
                    }

                }
            }
        }
        
        .onAppear {
            runRecordVM.fetchAllRunSummaries { loadedSummaries in
                self.summaries = loadedSummaries
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct InfoItem: View {
    let title: String
    let content: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.text01)
                .foregroundColor(.text_secondary)
            Text(content)
                .foregroundColor(.text_primary)
        }
    }
}

#Preview {
    RunningListView()
        .environmentObject(RunRecordViewModel())
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
}

extension Date {
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: self)
    }
    
    func formattedYMD() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: self)
    }

    func formattedHM() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: self)
    }

    func koreanWeekday() -> String {
        let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
        let calendar = Calendar(identifier: .gregorian)
        let weekdayIndex = calendar.component(.weekday, from: self) - 1
        return weekdaySymbols[weekdayIndex]
    }
}
