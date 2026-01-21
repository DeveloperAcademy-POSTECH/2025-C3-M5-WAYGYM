import SwiftUI

// weapon = 총 달린 거리 (꾸준함 보상), km
struct WeaponListView: View {
    @EnvironmentObject var runRecordStore: RunRecordStore
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    let weaponModel = WeaponModel()
    var selectedWeapon: WeaponDefinitionModel? {
        weaponModel.allWeapons.first(where: { $0.id == selectedWeaponId })
    }
    var acquisitionDate: Date? {
        guard let weapon = selectedWeapon, weapon.id != "0" else { return nil }
        return runRecordStore.weaponAcquiredAtById[weapon.id]
    }
    
    var body: some View {
            VStack {
                CustomNavigationBar(title: "무기 창고")
                
                // MARK: 진한 박스 zstack
                ZStack {
                    Color.gang_bg_primary_4
                    
                    VStack {
                        ZStack {
                            Image("Flash")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            
                            Image("main_\(selectedWeaponId)")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 230)
                                .padding(.bottom, -15)
                                .padding(.leading, -7)
                        }
                        .padding(.vertical, 15)
                        
                        VStack {
                            if let weapon = selectedWeapon, weapon.id != "0" {
                                Text(weapon.name)
                                    .padding(.vertical, 5)

                                Text(weapon.description)
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 16) {
                                    Spacer()
                                    
                                    if let date = acquisitionDate {
                                        Text("\(formatShortDate(date))")
                                    }
                                    
                                    Text("\(String(format: "%.0f", weapon.unlockNumber))km")
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
                        .padding(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black, lineWidth: 3)
                        )
                        .padding(.bottom, 20)
                        .padding(.horizontal, 14)
                        
                        
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                
                ScrollView {
                    let columns = [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ]
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(weaponModel.allWeapons) { weapon in
                            let isUnlocked = runRecordStore.unlockedWeaponIds.contains(weapon.id)
                            
                            if isUnlocked {
                                Button(action: {
                                    if selectedWeaponId == weapon.id {
                                        selectedWeaponId = "0"
                                    } else {
                                        selectedWeaponId = weapon.id
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
        .background { Color.gang_bg_primary_4.ignoresSafeArea()}
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    StatefulPreviewWrapper(nil as WeaponDefinitionModel?) { binding in
        WeaponListView()
            .environmentObject(RunRecordStore())
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
