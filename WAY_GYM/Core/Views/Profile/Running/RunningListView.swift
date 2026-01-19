import SwiftUI
import FirebaseFirestore

struct RunningListView: View {
    @EnvironmentObject private var runRecordService: RunRecordStore

    private var summaries: [RunRecordModel] {
        runRecordService.runRecords
    }

    private var groupedSummaries: [String: [RunRecordModel]] {
        Dictionary(grouping: summaries) { summary in
            RunRecordFormatters.monthKey.string(from: summary.startTime)
        }
    }

    private var sortedMonths: [String] {
        Array(groupedSummaries.keys).sorted(by: >)
    }

    var body: some View {
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
                            ForEach(sortedMonths, id: \.self) { month in
                                if let monthSummaries = groupedSummaries[month] {
                                    let monthTotalAreaM2 = monthSummaries.reduce(0) {
                                        $0 + ($1.capturedCellIds.count * 100) // 셀 1칸 = 100m² (임시)
                                    }
                                    let monthTotalDistanceM = monthSummaries.reduce(0.0) { $0 + $1.distanceM }

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(month)
                                            .font(.title02)

                                        HStack {
                                            Text("구역순찰 \(monthSummaries.count)회")
                                            Text("\(monthTotalAreaM2)m²")
                                            Text("\(String(format: "%.2f", monthTotalDistanceM / 1000))km")
                                        }
                                    }
                                    .font(.text02)
                                    .foregroundColor(.gang_text_1)
                                    .padding(.leading, 5)

                                    ForEach(monthSummaries) { summary in
                                        NavigationLink(
                                            destination: BigSingleRunningView(summary: summary)
                                                .foregroundColor(Color.gang_text_2)
                                                .font(.title01)
                                        ) {
                                            RunRecordCardView(summary: summary)
                                        }
                                    }

                                    Spacer().frame(height: 4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .backHiddenSwipeEnabled()
    }
}

private enum RunRecordFormatters {
    static let monthKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
}

#Preview {
    RunningListView()
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
        .environmentObject(RunRecordStore())
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
