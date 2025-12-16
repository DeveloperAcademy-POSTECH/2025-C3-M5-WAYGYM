import SwiftUI
import FirebaseFirestore

// minion = distance, 5000단위
struct MinionListView: View {
    @StateObject private var runrecordVM = RunRecordService()
    @StateObject private var Minionm = MinionModel()
    @StateObject private var vm = MinionListViewModel()
    
    var body: some View {
        ZStack {
            Color.gang_bg_profile
                .ignoresSafeArea()
                
            VStack {
                CustomNavigationBar(title: "똘마니들")
                
                ZStack {
                    Color.gang_bg_primary_4
                    
                    VStack{
                        // 캐릭터
                        ZStack {
                            Image("Flash")
                                .resizable()
                                .frame(width: 180, height: 170)
                            
                            if let selectedMinion = vm.selectedMinion {
                                Image(selectedMinion.id)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150)
                                    .padding(.bottom, -30)
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
                                if let minion = vm.selectedMinion {
                                    HStack {
                                        Text(minion.name)
                                        Spacer()
                                        Text(vm.acquisitionDateText)
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
                
                ScrollView {
                    let columns = [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(MinionModel.allMinions) { minion in
                            if vm.isMinionUnlocked(minion) {
                                Button(action: {
                                    vm.selectedMinion = minion
                                }) {
                                    MinionCard(minion: minion, isHighlighted: vm.selectedMinion?.id == minion.id)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                LockedMinionCard(minion: minion)
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
        .onAppear {
            runrecordVM.getTotalDistanceForRewards { total in
                vm.fetchUnlockedMinions(total ?? 0)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    MinionListView()
        .font(.text01)
        .foregroundColor(Color.gang_text_2)
}
