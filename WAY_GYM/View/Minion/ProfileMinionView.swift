import SwiftUI

struct ProfileMinionListView: View {
    @StateObject private var minionModel = MinionModel()
    @State private var userStats = UserModel(
        id: UUID(),
        runRecords: RunRecordModel.dummyData
    )
    
    var body: some View {
        HStack {
            let totalDistance = userStats.runRecords.map { $0.totalDistance }.reduce(0, +) / 1000
            
            let recentMinions = minionModel.allMinions
                .filter { totalDistance >= $0.unlockNumber }
                .suffix(3)
            
            VStack(alignment: .leading) {
                Text("사용자의 총거리: \(String(format: "%.3f", userStats.runRecords.map { $0.totalDistance }.reduce(0, +) / 1000))km")
                    .font(.subheadline)

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
            
            if recentMinions.count < 3  {
                Spacer()
            }
            
        }
    }
}

#Preview {
    ProfileMinionListView()
}
