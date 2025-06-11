import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ProfileView: View {
    @StateObject private var minionModel = MinionModel()
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    
    @EnvironmentObject var router: AppRouter
    
    @StateObject private var runRecordVM = RunRecordViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gang_bg_profile
                    .ignoresSafeArea()
                
                VStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 유저 설명 vstack
                            VStack {
                                ZStack {
                                    Image("Flash")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 220)
                                    
                                    Image("main_\(selectedWeaponId)")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 200)
                                        .padding(.bottom, -20)
                                    
                                    VStack {
                                        HStack {
                                            Spacer()
                                            VStack {
                                                NavigationLink(destination: WeaponListView()
                                                    .foregroundStyle(Color.gang_text_2)
                                                    .environmentObject(WeaponViewModel())
                                                    .environmentObject(runRecordVM))
                                                {
                                                    ZStack {
                                                        Image("box")
                                                            .resizable()
                                                            .frame(width: 52, height: 52)
                                                        
                                                        Image( "weapon_\(selectedWeaponId)")
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 40)
                                                    }
                                                }
                                                Text("무기")
                                                    .font(.title02)
                                            }
                                        }
                                        Spacer()
                                    } // 무기 선택
                                } // 유저 아이콘 zstack
                                .padding(3)
                                
                                Group {
                                    Text("한성인")
                                        .font(.title01)
                                        .padding(.bottom, 2)
                                    
                                    Text("남구 연일읍 1대손파 형님")
                                }
                                .foregroundStyle(Color.white)
                            } // 유저 설명 vstack
                            .padding(.bottom, 20)
                            
                            
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("총 차지한 영역")
                                        .font(.text01)
                                        .padding(.bottom, 8)
                                    
                                    Text("\(runRecordVM.totalCapturedAreaValue)m²")
                                        .font(.title01)
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .customBorder()
                                
                                Spacer()
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading) {
                                    Text("총 이동한 거리")
                                        .font(.text01)
                                        .padding(.bottom, 8)
                                    
                                    Text("\(formatDecimal(runRecordVM.totalDistance / 1000)) km")
                                        .font(.title01)
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .customBorder()
                            }
                            
                            VStack {
                                HStack {
                                    Text("나의 똘마니")
                                        .font(.title01)
                                    Spacer()
                                    NavigationLink(destination:
                                                    MinionListView()
                                                        .font(.text01)
                                                        .foregroundColor(Color.gang_text_2)) {
                                        Text("모두 보기")
                                            .foregroundStyle(Color.gang_highlight_3)
                                    }
                                    .opacity(hasUnlockedMinions ? 1 : 0)
                                    .disabled(!hasUnlockedMinions)
                                }
                                
                                ProfileMinionView()
                                    .padding(.vertical, 4)
                                    .font(.text01)
                                    .foregroundColor(Color.gang_text_2)
                                    
                            }
                            .padding(20)
                            .customBorder()
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("구역순찰 기록")
                                        .font(.title01)
                                    Spacer()
                                    NavigationLink(destination: RunningListView()
                                        .environmentObject(runRecordVM)
                                        .foregroundColor(Color.gang_text_2)
                                        .font(.title01)) {
                                        Text("모두 보기")
                                            .foregroundStyle(Color.gang_highlight_3)
                                    }
                                    .opacity(hasRunRecords ? 1 : 0)
                                    .disabled(!hasRunRecords)
                                }
                                
                                ProfileRunningView()
                                    .padding(.vertical, 4)
                                    .foregroundColor(Color.gang_text_2)
                                    .font(.title01)
                            }
                            .padding(20)
                            .customBorder()
                        }
                        .padding(.top, 70)
                    }
                    .scrollIndicators(.hidden)
                    .edgesIgnoringSafeArea(.top)
                    
                    Button(action: {
                        router.currentScreen = .main(id: UUID())
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black, lineWidth: 3)
                                )
                            
                            Text("구역 확장하러 가기")
                                .font(.title02)
                                .foregroundStyle(Color.black)
                                .padding(.vertical, 22)
                        }
                        .padding(.bottom, 5)
                    }
                    // .padding(.bottom, 5)
                    
                }
                .padding(.horizontal, 25)
            }
            .onAppear {
                runRecordVM.fetchAndSumDistances { total in
                    print("총 거리: \(total)")
                }
                runRecordVM.fetchAndSumCapturedValue()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .ignoresSafeArea(.all, edges: .top)
    }
}

// Computed property to check if any minions are unlocked
private extension ProfileView {
    var hasUnlockedMinions: Bool {
        let unlocked = minionModel.allMinions.filter { minion in
            return MinionViewModel().isUnlocked(minion, with: Int(runRecordVM.totalDistance))
        }
        return !unlocked.isEmpty
    }
}

#Preview {
    ProfileView()
        .environmentObject(MinionViewModel())
        .environmentObject(WeaponViewModel())
        .environmentObject(AppRouter())
        .environmentObject(RunRecordViewModel())
        .font(.text01)
        .foregroundColor(Color.gang_text_2)
}

private extension ProfileView {
    var hasRunRecords: Bool {
        runRecordVM.totalDistance > 0
    }
}
