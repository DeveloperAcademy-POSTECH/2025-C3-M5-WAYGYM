import SwiftUI
import FirebaseFirestore

struct ProfileMinionView: View {
    @StateObject var minionModel = MinionModel()
    @StateObject var minionVM = MinionViewModel()
    @ObservedObject var runRecordVM = RunRecordViewModel()
    
    @State private var recentMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []
    
    @State private var isLoading: Bool = true
    
    var body: some View {
            HStack {
                if isLoading {
                    VStack {
                        Text("로딩 중...")
                            .font(.text01)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    
                } else
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
                                if let trueIndex = minionModel.allMinions.firstIndex(where: { $0.id == minionData.minion.id }) {
                                                                  NavigationLink {
                                                                      MinionSingleView(minionModel: minionModel, minionIndex: trueIndex)
                                                                          .foregroundStyle(Color.gang_text_2)
                                                                          .font(.title01)
                                                                  } label: {
                                                                      MinionCard(minion: minionData.minion)
                                                                  }
                                }
                            }
                            if recentMinions.count < 3 {
                                Spacer()
                            }
                        }
                    }
                
            }
            .frame(height: .infinity)
            .onAppear {
                loadRecentMinions()
            }
        }
        
        private func loadRecentMinions() {
            isLoading = true
            
            runRecordVM.fetchAndSumDistances()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🟠 전체 미니언 수: \(minionModel.allMinions.count)")
                print("📏 총 거리: \(runRecordVM.totalDistance)")
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
                    self.recentMinions = minionsWithDates
                        .sorted { Int($0.minion.id) ?? 0 < Int($1.minion.id) ?? 0 }
                        .suffix(3)
                        .map { $0 }
                    
                }
                
                isLoading = false
                
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
