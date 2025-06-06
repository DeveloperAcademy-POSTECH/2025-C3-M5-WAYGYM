import SwiftUI
import FirebaseFirestore

struct ProfileMinionView: View {
    @StateObject var minionModel = MinionModel()
    @StateObject var minionVM = MinionViewModel()
    @ObservedObject var runRecordVM = RunRecordViewModel()
    
    @State private var recentMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []
    
    var body: some View {
            HStack {
                    if recentMinions.isEmpty {
                        VStack(alignment: .center) {
                            Text("이런..!\n내 똘마니들이 없잖아?!")
                            Text("\n구역확장을 해야겠어...!")
                        }
                        .padding(5)
                        .font(.text01)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    } else {
                        HStack(spacing: 16) {
                            ForEach(Array(recentMinions.enumerated()), id: \.element.minion.id) { index, minionData in
                                NavigationLink {
                                    MinionSingleView(minionModel: minionModel, minionIndex: index)
                                        .foregroundStyle(Color.gang_text_2)
                                        .font(.title01)
                                } label: {
                                    MinionCard(
                                        minion: minionData.minion
                                    )
                                }
                            }
                            if recentMinions.count < 3 {
                                Spacer()
                            }
                        }
                    }
                
            }
            .frame(height:.infinity)
            .onAppear {
                loadRecentMinions()
            }
        }
        
        private func loadRecentMinions() {
            runRecordVM.fetchAndSumDistances()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let unlockedMinions = minionModel.allMinions.filter { minion in
                    minionVM.isUnlocked(minion, with: Int(runRecordVM.totalDistance))
                }
                
                // 각 미니언의 획득 날짜를 계산
                let group = DispatchGroup()
                var minionsWithDates: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []
                
                for minion in unlockedMinions {
                    group.enter()
                    runRecordVM.fetchRunRecordsAndCalculateMinionAcquisitionDate(for: minion.unlockNumber) { date in
                        if let acquisitionDate = date {
                            minionsWithDates.append((minion: minion, acquisitionDate: acquisitionDate))
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    // 획득 날짜 기준으로 최신순 정렬하고 최근 3개만 선택
                    self.recentMinions = minionsWithDates
                        .sorted { $0.minion.id < $1.minion.id }
                        .prefix(3)
                        .map { $0 }
                    
                }
            }
        }
    }
    
struct MinionCard: View {
    let minion: MinionDefinitionModel
    
    var body: some View {
        ZStack {
            Image("minion_box")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.width * 0.25)
            
            VStack {
                Image(minion.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80)
                    .shadow(color: .black, radius: 2)
                
                Text(minion.name)
                    .foregroundStyle(Color.black)
                
                Text(String(format: "%.0f km", minion.unlockNumber))
                    .foregroundColor(.black)
            }
            
        }
        
        
    }
}

#Preview {
    ProfileMinionView()
        .font(.text01)
        .foregroundColor(Color.gang_text_2)
}
