import SwiftUI

// weapon = area, 1,000,000단위
struct WeaponListView: View {
    @StateObject private var weaponModel = WeaponModel()
    @State private var inputCaptureArea: String = ""
    @State private var userStats = UserModel(
        id: UUID(),
        runRecords: RunRecordModel.dummyData
    )
    // @State private var selectedWeapon: WeaponDefinitionModel? = nil
    @Binding var selectedWeapon: WeaponDefinitionModel?
    @EnvironmentObject var weaponVM: WeaponViewModel

    var body: some View {
        VStack {
            VStack{
                Image(selectedWeapon != nil ? "main_\(selectedWeapon!.id)" : "main_basic")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)
                
                if let weapon = selectedWeapon {
                    Text(weapon.name)
                    Text(weapon.description)
                        .multilineTextAlignment(.center)
                
                } else {
                    Text("맨손")
                    Text("무기가 없어도\n뭐 문제있나?")
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 20)
            
            Text("나의 총 땅: \(String(format: "%.2f", weaponVM.totalCaptureArea(from: userStats.runRecords) / 1_000_000)) km²")
                .font(.subheadline)
            
            ScrollView {
                let columns = [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(weaponModel.allWeapons) { weapon in
                        let isUnlocked = weaponVM.isWeaponUnlocked(weapon, for: userStats.runRecords)

                        if isUnlocked {
                            Button(action: {
                                selectedWeapon = weapon
                            }) {
                                ZStack {
                                    Color.white
                                    VStack {
                                        Image(weapon.imageName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50)

                                        Text(weapon.name)
                                            .font(.body)

                                        Text("\(Int(weapon.unlockNumber))km²")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 100, height: 120)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                                .overlay {
                                    if selectedWeapon?.id == weapon.id {
                                        Image("selected")
                                            .resizable()
                                            .frame(width: 120, height: 140)
                                    }
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

                                    Text("\(Int(weapon.unlockNumber))km²")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: 100, height: 120)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                    }
                }
            }
            
        }
        .padding()
        .navigationTitle("무기 창고")
    }
}


