import SwiftUI
import FirebaseFirestore

struct ProfileMinionView: View {
    @StateObject var minionModel = MinionModel()
    @StateObject var minionVM = MinionViewModel()
    @ObservedObject var runRecordVM = RunRecordViewModel()
    
    @State private var recentMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []
    
    @State private var isLoading: Bool = true
    
    @State private var hasLoaded = false
    
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
        .frame(maxHeight: .infinity)
        .onAppear {
            if !hasLoaded {
                loadRecentMinions()
                hasLoaded = true
            }
        }
    }
    
    private func loadRecentMinions() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🟠 전체 미니언 수: \(minionModel.allMinions.count)")

            runRecordVM.fetchAndSumDistances { total in
                print("📏 총 거리(콜백): \(total)")

                let unlockedMinions = minionModel.allMinions.filter { minion in
                    minionVM.isUnlocked(minion, with: Int(total))
                }

                let sortedMinions = unlockedMinions
                    .sorted { Int($0.id) ?? 0 < Int($1.id) ?? 0 }
                    .suffix(3)

                self.recentMinions = sortedMinions.map { minion in
                    (minion: minion, acquisitionDate: Date()) // placeholder date
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
    
}

#Preview {
    ProfileMinionView()
        .font(.text01)
        .foregroundColor(Color.gang_text_2)
}
