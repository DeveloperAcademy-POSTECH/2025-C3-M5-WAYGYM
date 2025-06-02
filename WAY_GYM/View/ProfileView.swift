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
    
    @State private var selectedWeapon: WeaponDefinitionModel? = nil
    
    var body: some View {
        NavigationView {
                ZStack {
                    Color.gray
                        .ignoresSafeArea()
                    
                    ScrollView{
                        VStack {
                            ZStack {
                                Color.black
                                
                                VStack {
                                    HStack {
                                        Spacer()
                                        VStack {
                                            NavigationLink(destination: WeaponListView(selectedWeapon: $selectedWeapon)
                                                .environmentObject(WeaponViewModel())) {
                                                Rectangle()
                                                    .foregroundStyle(Color.white)
                                                    .frame(width: 50, height: 50)
                                            }
                                            Text("무기")
                                                .foregroundStyle(Color.white)
                                        }
                                        
                                    }
                                    Spacer()
                                }
                                .padding(20)
                                
                                VStack {
                                    Image(selectedWeapon != nil ? "main_\(selectedWeapon!.id)" : "main_basic")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 130)
                                        .padding(.bottom, 15)
                                    
                                    Group {
                                        Text("한성인")
                                            .font(.title)
                                        
                                        Text("남구 연일읍 1대손파 형님")
                                    }
                                    .foregroundStyle(Color.white)
                                }
                            } // 프로필 zstack
                            .clipShape(RoundedRectangle(cornerRadius: 40))
                            .frame(width: 330, height: 330)
                            .padding(.bottom, 20)
                            
                            Text("나의 총거리: \(String(format: "%.3f", userStats.runRecords.map { $0.totalDistance }.reduce(0, +) / 1000))km")
                                .font(.subheadline)
                            Text("나의 총 땅: \(String(format: "%.2f", userStats.runRecords.map { $0.capturedAreaValue }.reduce(0, +) / 1_000_000)) km²")
                            
                            VStack {
                                VStack{
                                    HStack {
                                        Text("나의 똘마니")
                                            .font(.headline)
                                        Spacer()
                                        NavigationLink(destination: MinionListView()
                                            .environmentObject(MinionViewModel())) {
                                            Text("모두 보기")
                                        }
                                    }
                                    
                                    HStack {
                                        ProfileMinionListView()
                                    }
                                    .padding(.bottom, 20)
                                }
                                .padding()
                                .border(Color.black, width: 3)
                                
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("나의 땅따먹기 기록")
                                            .font(.headline)
                                        Spacer()
                                        NavigationLink(destination: RunningListView()) {
                                            Text("모두 보기")
                                        }
                                    }
                                        ProfileRunningView()
                                       
                                }
                                .padding()
                                .border(Color.black, width: 3)
                                
                            }// 똘마니, 기록 vstack
                            .padding(.horizontal, 30)
                        }
                    }
                    
                }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(MinionViewModel())
        .environmentObject(WeaponViewModel())
}
