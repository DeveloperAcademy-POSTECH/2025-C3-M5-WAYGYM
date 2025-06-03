import SwiftUI

// weapon = area, 1,000,000단위
struct WeaponListView: View {
    @StateObject private var weaponModel = WeaponModel()
    // @State private var userStats = UserModel(id: UUID(), runRecords: [])
    // @State private var selectedWeapon: WeaponDefinitionModel? = nil
    @Binding var selectedWeapon: WeaponDefinitionModel?
    @EnvironmentObject var weaponVM: WeaponViewModel
    
    @StateObject private var runRecordVM = RunRecordViewModel()
    @State private var acquisitionDate: Date? = nil
    
    var body: some View {
        ZStack {
            Color.gang_bg_profile
                .ignoresSafeArea()
            
            VStack {
                CustomNavigationBar(title: "무기 창고")
                
                // 진한 박스 zstack
                ZStack {
                    Color.gang_bg_primary_4
                    
                    VStack {
                        // 사용자 이미지
                        ZStack {
                            Image("Flash")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 200)
                            
                            Image((selectedWeapon == nil || selectedWeapon?.id == "0") ? "main_basic" : "main_\(selectedWeapon!.id)")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 230)
                                .padding(.bottom, -15)
                        } // 사용자 이미지 zstack
                        .padding(.vertical, 15)
                        
                        VStack {
                            if let weapon = selectedWeapon, weapon.id != "0" {
                                Text(weapon.name)
                                    .padding(.vertical, 5)

                                Text(weapon.description)
                                    .multilineTextAlignment(.center)

                                HStack {
                                    Spacer()
                                    
                                    if let date = acquisitionDate {
                                        Text("\(formatShortDate(date))")
                                    }
                                    
                                    Text("\(Int(weapon.unlockNumber))m²")
                                }
                                .font(.title02)
                                .padding(.vertical, 1)

                            } else {
                                Text("맨손")
                                    .padding(.vertical, 5)

                                Text("무기? 필요 있나?\n내 주먹이 무기인데")
                                    .multilineTextAlignment(.center)

                                HStack {
                                    Spacer()
                                    Text("00")
                                    Text("00.00.00")
                                }
                                .font(.title02)
                                .foregroundStyle(Color("gang_bg_primary_4"))
                                .padding(.vertical, 1)

                            }
                        }
                        .font(.title01)
                        .frame(maxWidth: .infinity)
                        .padding(16) // 박스 내부 여백
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 3)
                        )
                        .padding(.bottom, 20)
                        .padding(.horizontal, 14)
                        
                        
                    }
                } // 진한 박스 zstack
                .frame(height: UIScreen.main.bounds.height * 0.5)
                
                //                Text("나의 총 땅: \(Int(weaponVM.totalCaptureArea(from: userStats.runRecords)))m²")
                //                    .font(.subheadline)
                
                ScrollView {
                    let columns = [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ]
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(weaponModel.allWeapons) { weapon in
                            // let isUnlocked = Double(runRecordVM.totalCapturedAreaValue) >= weapon.unlockNumber
                            let isUnlocked = weaponVM.isUnlocked(weapon, with: runRecordVM.totalCapturedAreaValue)
                            
                            if isUnlocked {
                                Button(action: {
                                    if selectedWeapon?.id == weapon.id {
                                        selectedWeapon = nil
                                    } else {
                                        selectedWeapon = weapon
                                    }
                                }) {
                                    ZStack {
                                        Image("box")
                                            .resizable()
                                            .frame(width: UIScreen.main.bounds.width * 0.25, height: UIScreen.main.bounds.width * 0.25)
                                        
                                        VStack {
                                            Image(weapon.imageName)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 90)
                                        }
                                    }
                                    // .frame(width: 100, height: 120)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                    .overlay {
                                        if selectedWeapon?.id == weapon.id {
                                            Image("selected")
                                                .resizable()
                                                .frame(width: UIScreen.main.bounds.width * 0.25, height: UIScreen.main.bounds.width * 0.25)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Image("unlockbox")
                                    .resizable()
                                    .frame(width: UIScreen.main.bounds.width * 0.25, height: UIScreen.main.bounds.width * 0.25)
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
                .padding(.horizontal, 14)
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            runRecordVM.fetchAndSumCapturedValue()
        }
        .onChange(of: selectedWeapon) { newWeapon in
            if let weapon = newWeapon {
                runRecordVM.fetchRunRecordsAndCalculateWeaponAcquisitionDate(for: weapon.unlockNumber) { date in
                    print("선택 무기 변경, 획득 날짜: \(String(describing: date))")
                    acquisitionDate = date
                }
            } else {
                acquisitionDate = nil
            }
        }
        .navigationBarBackButtonHidden(true)
    }

//    private var acquisitionDate: Date? {
//        guard let weapon = selectedWeapon else { return nil }
//        var cumulative: Double = 0
//        for record in runRecordVM.runRecords {
//            cumulative += Double(record.capturedAreaValue)
//            if cumulative >= weapon.unlockNumber {
//                return record.startTime
//            }
//        }
//        return nil
//    }
    
}

let runRecordVM = RunRecordViewModel()
let weaponVM = WeaponViewModel()
#Preview {
    StatefulPreviewWrapper(nil as WeaponDefinitionModel?) { binding in
        WeaponListView(selectedWeapon: binding)
            .environmentObject(runRecordVM)
            .environmentObject(weaponVM)
            .font(.text01)
            .foregroundColor(Color.gang_text_2)
    }
}

struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(wrappedValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
