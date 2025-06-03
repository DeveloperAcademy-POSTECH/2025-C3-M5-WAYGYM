//import SwiftUI
//
//// weapon = area, 1,000,000단위
//struct WeaponListView2: View {
//    @StateObject private var weaponModel = WeaponModel()
//    @State private var inputCaptureArea: String = ""
//    @State private var userStats = UserModel(
//        id: UUID(),
//        runRecords: RunRecordModel.dummyData
//    )
//    // @State private var selectedWeapon: WeaponDefinitionModel? = nil
//    @Binding var selectedWeapon: WeaponDefinitionModel?
//    @EnvironmentObject var weaponVM: WeaponViewModel
//    
//    var body: some View {
//        ZStack {
//            Color.gray
//                .ignoresSafeArea()
//            
//            VStack {
//                ZStack {
//                    Color.brown
//                    VStack{
//                        // 사용자 캐릭터
//                        ZStack {
//                            Image("Flash")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 220)
//                            
//                            Image(selectedWeapon != nil ? "main_\(selectedWeapon!.id)" : "main_basic")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 220)
//                        }
//                        .padding(.vertical, 12)
//
//                        VStack {
//                            if let weapon = selectedWeapon, weapon.id != "1" {
//                                Text(weapon.name)
//                                    .padding(.bottom, 5)
//                                
//                                Text(weapon.description)
//                                    .multilineTextAlignment(.center)
//                                
//                                if let date = weaponVM.acquisitionDate(for: weapon, in: userStats.runRecords) {
//                                    Text("획득 날짜: \(formatDate(date))")
//                                }
//                            } else {
//                                Text("맨손")
//                                    .padding(.bottom, 5)
//                                Text("무기...? 없어도\n뭐 문제있나?")
//                                    .multilineTextAlignment(.center)
//                            }
//                        }
//                        .font(.title01)
//                        .frame(maxWidth: .infinity)
//                        .padding(16)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 16)
//                                .stroke(Color.black, lineWidth: 3)
//                        )
//                        .padding(.bottom, 20)
//                        .padding(.horizontal, 14)
//                        
//                    }
//                }
//                .frame(height: UIScreen.main.bounds.height * 0.5)
//                .overlay(
//                    Rectangle()
//                        .fill(Color.black)
//                        .frame(height: 3)
//                        .frame(maxHeight: .infinity, alignment: .bottom)
//                )
//                .padding(.bottom, 20)
//                .padding(.horizontal, -8)
//
//                //                Text("나의 총 땅: \(String(format: "%.2f", weaponVM.totalCaptureArea(from: userStats.runRecords) / 1_000_000)) km²")
//                //                    .font(.subheadline)
//                
//                ScrollView {
//                    let columns = [
//                        GridItem(.flexible()),
//                        GridItem(.flexible()),
//                        GridItem(.flexible())
//                    ]
//                    LazyVGrid(columns: columns, spacing: 30) {
//                        ForEach(weaponModel.allWeapons) { weapon in
//                            let isUnlocked = weaponVM.isWeaponUnlocked(weapon, for: userStats.runRecords)
//                            
//                            if isUnlocked {
////                                Button(action: {
////                                    //
////                                }) {
//                                    ZStack {
//                                        Image("box")
//                                            .resizable()
//                                            .frame(width: UIScreen.main.bounds.width * 0.25, height: UIScreen.main.bounds.width * 0.25)
//                                        
//                                        VStack {
//                                            Image(weapon.imageName)
//                                                .resizable()
//                                                .aspectRatio(contentMode: .fit)
//                                                .frame(width: 90)
//                                        }
//                                        
//                                        if selectedWeapon {
//                                            Image("selected")
//                                                .resizable()
//                                                .aspectRatio(contentMode: .fit)
//                                                .frame(width: UIScreen.main.bounds.width * 0.25)
//                                        }
//                                    }
//                                    .background(Color(.systemGray6))
//                                    .cornerRadius(8)
//                                    .shadow(radius: 2)
////                                }
////                                .buttonStyle(PlainButtonStyle())
//                            }
////                            else {
////                                ZStack {
////                                    Image("unlockbox")
////                                        .resizable()
////                                        .frame(width: UIScreen.main.bounds.width * 0.25, height: UIScreen.main.bounds.width * 0.25)
////
////                                }
////                                .background(Color(.systemGray6))
////                                .cornerRadius(8)
////                                .shadow(radius: 2)
////                            }
//                        }
//                    }
//                    .padding(16)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 16)
//                            .stroke(Color.black, lineWidth: 7)
//                    )
//                    .clipShape(RoundedRectangle(cornerRadius: 16))
//                }
//            }
//            .padding(.horizontal, 14)
//        }
//        .navigationTitle("무기 창고")
//    }
//}
