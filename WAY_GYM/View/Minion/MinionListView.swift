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
        ZStack {
            Color.gray
                .ignoresSafeArea()
                
            VStack {
                CustomNavigationBar(title: "똘마니들")
                
                ZStack {
                    Color.brown
                    
                    VStack{
                        // 캐릭터
                        ZStack {
                            Image("Flash")
                                .resizable()
                                .frame(width: 180, height: 170)
                            
                            if let selectedMinion = selectedMinion {
                                Image(selectedMinion.id)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150)
                                    .padding(.bottom, -45)
                            } else {
                                Image("questionMark")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150)
                            }
                        }
                        
                        // 설명
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 3)
                                .frame(maxWidth: .infinity)
                                .frame(height: 124)
                            
                            VStack {
                                if let minion = selectedMinion {
                                    HStack {
                                        Text(minion.name)
                                        Spacer()
                                        if let date = minionVM.acquisitionDate(for: minion, in: userStats.runRecords) {
                                            Text("\(formatShortDate(date))")
                                        }
                                    }
                                    .padding(.horizontal, 26)
                                    
                                    Text(minion.description)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 6)
                                        
                                } else {
                                    Text("똘마니를\n선택해주세요.")
                                        .multilineTextAlignment(.center)
                                }
                            } // 설명 vstack
                            .font(.title01)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.4)
                .overlay(
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )
                .padding(.bottom, 5)
                .padding(.horizontal, -14)
                
                
//                Text("사용자의 총거리: \(String(format: "%.3f", userStats.runRecords.map { $0.totalDistance }.reduce(0, +) / 1000))km")
//                    .font(.subheadline)
                
                ScrollView {
                    let columns = [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ]
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(minionModel.allMinions) { minion in
                            // let isUnlocked = true
                            let isUnlocked = userStats.runRecords.map { $0.totalDistance }.reduce(0, +) >= minion.unlockNumber * 1000
                            if isUnlocked {
                                Button(action: {
                                    selectedMinion = minion
                                }) {
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
                                                // .shadow(color: isSelected ? Color.yellow : Color.black, radius: 4, x: 0, y: 0)
                                                .shadow(color: selectedMinion?.id == minion.id ? Color.yellow : Color.black, radius: 4, x: 0, y: 0)
                                            
                                            Text(minion.name)
                                                .foregroundStyle(Color.black)
                                            
                                            Text(String(format: "%.0f km", minion.unlockNumber))                    .foregroundStyle(Color.black)
                                        }
                                    }
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                ZStack {
                                    Image("minion_box")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: UIScreen.main.bounds.width * 0.25)
                                    
                                    VStack {
                                        Image("questionMark")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 80)
                                            .shadow(color: Color.black, radius: 4, x: 0, y: 0)
                                        
                                        Text("???")
                                            .foregroundStyle(Color.black)
                                        
                                        Text(String(format: "%.0f km", minion.unlockNumber))
                                            .foregroundStyle(Color.black)
                                    }
                                }
                                .cornerRadius(8)
                            }
                        }
                    }
                        .padding(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 7)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 14)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    MinionListView()
        .environmentObject(MinionViewModel())
        .font(.text01)
        .foregroundColor(.white)
}
