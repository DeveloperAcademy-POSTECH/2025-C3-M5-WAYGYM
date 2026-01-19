import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ProfileView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    @StateObject private var minionModel = MinionModel()
    @EnvironmentObject var runRecordService: RunRecordStore
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    @State private var hasUnlockedMinions: Bool = false
    
    var hasRunRecords: Bool {
        runRecordService.totalDistance > 0
    }
    
    var body: some View {
        ZStack {
            Color.gang_bg_profile
                .ignoresSafeArea()
            
            VStack {
                ScrollView {
                    VStack(spacing: 16) {
                        userSection
                        
                        statsSection
                        
                        minionsSection
                        
                        runningRecordsSection
                    }
                    .padding(.top, 70)
                }
                .scrollIndicators(.hidden)
                .edgesIgnoringSafeArea(.top)
                
                CustomButton(title: "구역 확장하러 가기") {
                    coordinator.popToRoot()
                }
            }
            .padding(.horizontal, 25)
        }
        .backHiddenSwipeEnabled()
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            Task {
                await checkHasUnlockedMinions()
            }
        }
    }

    private var userSection: some View {
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

                weaponSelectButton
            }
            .padding(3)

            Group {
                Text("한성인")
                    .font(.title01)
                    .padding(.bottom, 2)

                Text("남구 연일읍 1대손파 형님")
            }
            .foregroundStyle(Color.white)
        }
        .padding(.bottom, 20)
    }

    private var weaponSelectButton: some View {
        VStack {
            HStack {
                VStack {
                    ZStack {
                        Image("box")
                            .resizable()
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "gear")
                            .font(.system(size: 25))
                            .foregroundStyle(Color.gangBgWOpacity)
                    }
                    .onTapGesture {
                        coordinator.push(.setting)
                    }
                    
                    Text("설정")
                        .font(.title02)
                }
                
                Spacer()

                VStack {
                    ZStack {
                        Image("box")
                            .resizable()
                            .frame(width: 52, height: 52)
                        
                        Image("weapon_\(selectedWeaponId)")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40)
                    }
                    .onTapGesture {
                        coordinator.push(.weaponList)
                    }
                    
                    Text("무기")
                        .font(.title02)
                }
            }
            Spacer()
        }
    }

    private var statsSection: some View {
        HStack {
            statCard(
                title: "총 차지한 영역",
                value: "\(runRecordService.totalCapturedAreaValue)m²"
            )

            Spacer().frame(width: 16)

            statCard(
                title: "총 이동한 거리",
                value: "\(formatDecimal(runRecordService.totalDistance / 1000)) km"
            )
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.text01)
                .padding(.bottom, 8)

            Text(value)
                .font(.title01)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .customBorder()
    }

    private var minionsSection: some View {
        VStack {
            HStack {
                Text("나의 똘마니")
                    .font(.title01)
                
                Spacer()
                
                Text("모두 보기")
                    .foregroundStyle(Color.gang_highlight_3)
                    .onTapGesture {
                        coordinator.push(.minionList)
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
    }

    private var runningRecordsSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("구역순찰 기록")
                    .font(.title01)
                
                Spacer()
                
                Text("모두 보기")
                    .foregroundStyle(Color.gang_highlight_3)
                    .onTapGesture {
                        coordinator.push(.runningList)
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
    
    private func checkHasUnlockedMinions() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            hasUnlockedMinions = false
            return
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("Users")
                .document(uid)
                .collection("minionUnlocks")
                .limit(to: 1)
                .getDocuments()

            hasUnlockedMinions = !snapshot.documents.isEmpty
        } catch {
            hasUnlockedMinions = false
        }
    }
}
