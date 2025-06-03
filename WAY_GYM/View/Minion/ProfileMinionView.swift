import SwiftUI

struct ProfileMinionListView: View {
    let recentMinions: [MinionDefinitionModel]
    @State private var userStats = UserModel(
        id: UUID(),
        runRecords: RunRecordModel.dummyData
    )
    @StateObject private var minionModel = MinionModel()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
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
                        ForEach(recentMinions, id: \.id) { minion in
                            NavigationLink(destination: MinionSingleView(minion: minion)) {
                                VStack {
                                    Image(minion.iconName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50)
                                    
                                    Text(minion.name)
                                    Text(String(format: "%.0f km", minion.unlockNumber))
                                }
                                .frame(width: 100, height: 120)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            if recentMinions.count < 3 {
                Spacer()
            }
        }
    }
}
