import SwiftUI

struct ProfileView: View {
    @StateObject private var userVM = UserViewModel(user: UserModel(
        id: UUID(),
        runRecords: RunRecordModel.dummyData
    ))
    @State private var userStats = UserModel(
        id: UUID(),
        runRecords: RunRecordModel.dummyData
    )
    
    @StateObject private var minionModel = MinionModel()
    @State private var selectedWeapon: WeaponDefinitionModel? = nil
    
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        let totalDistance = userStats.runRecords.map { $0.totalDistance }.reduce(0, +) / 1000
        let recentMinions = minionModel.allMinions
            .filter { totalDistance >= $0.unlockNumber }
            .suffix(3)
        let hasRecentMinions = !recentMinions.isEmpty
        
        NavigationView {
                ZStack {
                    Color("gang_bg_profile")
                        .ignoresSafeArea()
                    
                    ScrollView{
                        VStack(spacing: 16) {
                                // 유저 설명 vstack
                                VStack {
                                    ZStack {
                                        Image("Flash")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 180)
                                        
                                        Image(selectedWeapon != nil ? "main_\(selectedWeapon!.id)" : "main_basic")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 200)
                                            .padding(.bottom, -20)
                                        
                                        VStack {
                                            HStack {
                                                Spacer()
                                                VStack {
                                                    NavigationLink(destination: WeaponListView(selectedWeapon: $selectedWeapon)
                                                        .foregroundStyle(Color("gang_text_2"))
                                                        .environmentObject(WeaponViewModel())) {
                                                            ZStack {
                                                                Image("box")
                                                                    .resizable()
                                                                    .frame(width: 52, height: 52)
                                                                
                                                                Image(selectedWeapon?.imageName ?? "weapon_0")
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
                                    .padding()
                                    
                                    Group {
                                        Text("한성인")
                                            .font(.title01)
                                            .padding(.bottom, 2)
                                        
                                        Text("남구 연일읍 1대손파 형님")
                                    }
                                    .foregroundStyle(Color.white)
                                } // 유저 설명 vstack
                                .padding(.bottom, 15)

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("총 차지한 영역")
                                            .font(.text01)
                                            .padding(.bottom, 8)
                                        
                                        Text(" \(formatNumber(userStats.runRecords.map { $0.capturedAreaValue }.reduce(0, +))) m²")                     .font(.title01)
                                    }
                                    .padding(20)
                                    .customBorder()
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .leading) {
                                        Text("총 이동한 거리")
                                            .font(.text01)
                                            .padding(.bottom, 8)
                                        
                                        Text("\(formatNumber(userStats.runRecords.map { $0.totalDistance }.reduce(0, +) / 1000))km")
                                            .font(.title01)
                                    }
                                    .padding(20)
                                    .customBorder()
                                }
                                
                                VStack{
                                    HStack {
                                        Text("나의 똘마니")
                                            .font(.title01)
                                        Spacer()
                                        NavigationLink(destination: MinionListView()
                                            .environmentObject(MinionViewModel())) {
                                                Text("모두 보기")
                                            }
                                            .opacity(hasRecentMinions ? 1 : 0)
                                            .disabled(!hasRecentMinions)
                                    }
                                    
                                    ProfileMinionListView(recentMinions: Array(recentMinions))
                                        .padding(.vertical, 4)
                                        .foregroundStyle(Color.black)
                                    
                                }
                                .padding(20)
                                .customBorder()
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("구역순찰 기록")
                                            .font(.title01)
                                        Spacer()
                                        if hasRecentMinions {
                                            NavigationLink(destination: RunningListView()) {
                                                Text("모두 보기")
                                            }
                                        }
                                    }
                                    ProfileRunningView()
                                        .padding(.vertical, 4)
                                        .foregroundStyle(Color.black)
                                    
                                }
                                .padding(20)
                                .customBorder()
                            
                        }
                        .padding(.horizontal, 25)
                    }
                    
                    VStack {
                        Spacer()
                        
                        // 홈 버튼
                        Button(action: {
                            router.currentScreen = .main
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
                            .padding(.horizontal, 25)
                        }
                        .padding(.bottom, 5)
                    }
                    
                    
                }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(MinionViewModel())
        .environmentObject(WeaponViewModel())
        .font(.text01)
        .foregroundColor(Color("gang_text_2"))
}


struct CustomBorderModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .overlay(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                    Spacer()
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 4)
                }
                .padding(.horizontal, 2)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.black, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func customBorder(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(CustomBorderModifier(cornerRadius: cornerRadius))
    }
}
