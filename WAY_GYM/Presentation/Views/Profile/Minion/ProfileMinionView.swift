import SwiftUI
import FirebaseAuth

struct ProfileMinionView: View {
    @StateObject var minionModel = MinionModel()
    private let rewardRepository: RewardRepositoryProtocol
    
    @State private var recentMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []
    
    @State private var isLoading: Bool = true
    
    @State private var hasLoaded = false

    init(rewardRepository: RewardRepositoryProtocol = RewardRepository()) {
        self.rewardRepository = rewardRepository
    }
    
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
                hasLoaded = true
                Task { await loadRecentMinions() }
            }
        }
    }

    @MainActor
    private func loadRecentMinions() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            recentMinions = []
            isLoading = false
            return
        }

        do {
            let unlocks = try await rewardRepository.fetchMinionUnlocks(uid: uid)
            let mapped: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = unlocks.compactMap { unlock in
                guard let minionId = Int(unlock.minionId),
                      let minion = minionModel.allMinions.first(where: { $0.minionId == minionId }) else {
                    return nil
                }
                return (minion: minion, acquisitionDate: unlock.unlockedAt)
            }

            // 가장 최근 해금 순으로 최대 3개만 노출
            recentMinions = Array(mapped.prefix(3))
            isLoading = false
        } catch {
            recentMinions = []
            isLoading = false
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
