import SwiftUI

struct ProfileMinionView: View {
    @StateObject private var vm: ProfileMinionViewModel
    
    init(runRecordVM: RunRecordService = RunRecordService()) {
        _vm = StateObject(wrappedValue: ProfileMinionViewModel(runRecordVM: runRecordVM))
    }
    
    var body: some View {
        HStack {
            if vm.isLoading {
                VStack {
                    Text("로딩 중...")
                        .font(.text01)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                
            } else if vm.recentMinions.isEmpty {
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
                    ForEach(vm.recentMinionsWithIndex, id: \.minion.id) { item in
                        NavigationLink {
                            MinionSingleView(minionIndex: item.index)
                                .foregroundStyle(Color.gang_text_2)
                                .font(.title01)
                        } label: {
                            MinionCard(minion: item.minion)
                        }
                    }
                    if vm.recentMinions.count < 3 {
                        Spacer()
                    }
                }
            }
            
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            vm.loadIfNeeded()
        }
    }
    
}

#Preview {
    ProfileMinionView()
        .font(.text01)
        .foregroundColor(Color.gang_text_2)
}
