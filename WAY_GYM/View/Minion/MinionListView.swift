import SwiftUI

// minion = distance, 5000단위
struct MinionListView: View {
    @StateObject private var minionModel = MinionModel()
    @State private var userStats = UserModel(
        id: UUID(),
        runRecords: RunRecordModel.dummyData
    )
    @State private var selectedMinion: MinionDefinitionModel? = nil
    @EnvironmentObject var minionVM: MinionViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            VStack{
                Image(selectedMinion != nil ? "\(selectedMinion!.id)" : "questionMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)
                
                if let minion = selectedMinion {
                        Text(minion.name)
                        Text(minion.description)
                            .multilineTextAlignment(.center)
                    
                    if let date = minionVM.acquisitionDate(for: minion, in: userStats.runRecords) {
                               Text("획득 날짜: \(formatDate(date))")
                           }
                }
            }
            .padding(.bottom, 20)
            
            Text("사용자의 총거리: \(String(format: "%.3f", userStats.runRecords.map { $0.totalDistance }.reduce(0, +) / 1000))km")
                .font(.subheadline)
            
            ScrollView {
                let columns = [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(minionModel.allMinions) { minion in
                        let isUnlocked = userStats.runRecords.map { $0.totalDistance }.reduce(0, +) >= minion.unlockNumber * 1000
                        if isUnlocked {
                            Button(action: {
                                selectedMinion = minion
                            }) {
                                ZStack {
                                    Color.white
                                    VStack {
                                        Image(minion.iconName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50)
                                        Text(minion.name)
                                            .font(.body)
                                        Text(String(format: "%.0f km", minion.unlockNumber))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 100, height: 120)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedMinion?.id == minion.id ? Color.red : Color.clear, lineWidth: 1)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            ZStack {
                                Color.white
                                VStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50)
                                        .foregroundColor(.gray)
                                    Text(String(format: "%.0f km", minion.unlockNumber))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: 100, height: 120)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
        }
        .navigationTitle("똘마니들")
    }
}

#Preview {
    MinionListView()
        .environmentObject(MinionViewModel())
}
