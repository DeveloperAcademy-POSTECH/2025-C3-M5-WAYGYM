import SwiftUI
import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import FirebaseCore

enum RunPhase: Equatable {
    case root /// 기본, 결과 모달 닫았을 때 활성화
    case countingDown(Int) // countingDown - 런닝 재생 시 뜨는 3,2,1 화면. 재생 버튼 탭할 시, isCountingDown == true일 때 활성화
    case running // 런닝 중
    case finishing(progress: CGFloat) /// 길게 눌러 런닝 종료 중일 때. 정지 버튼 길게 누르기 시작했을때  활성화.
    case runResult /// 길게 누른 후 손 땠을 때 활성화
}

struct MainView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var runRecordStore: RunRecordStore
    @StateObject var vm: MainViewModel
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MapView(
                region: $locationManager.region,
                polylines: locationManager.polylines,
                polygons: locationManager.polygons,
                currentLocation: $locationManager.currentLocation,
                selectedWeaponId: selectedWeaponId,
                shouldRenderPolylines: locationManager.isSimulating
            )
            .edgesIgnoringSafeArea(.all)
            
            // 내 활동 구역 이동 버튼
            if vm.runPhase == .root {
                VStack(spacing: 10) {
                    HStack{
                        VStack(spacing: 30) {
                            VStack(spacing: -20) {
                                Button {
                                    coordinator.push(.friend)
                                } label: {
                                    Image("friendIcon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                }
                                Text("접수 대상 찾기")
                                    .font(.text02)
                                    .foregroundColor(.white)
                            }
                            
                            VStack {
                                Button {
                                    coordinator.push(.profile)
                                } label: {
                                    Image("ProfilIcon")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                }
                                Text("내 활동 기록")
                                    .font(.text02)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 15)
                    
                    Spacer()
                }
            }
            
            HStack {
                Spacer()
                VStack {
                    ControlPanel(
                        runPhase: vm.runPhase,
                        onTapStartRun: {
                            vm.tapPlay(locationManager: locationManager, currentTotalDistanceM: runRecordStore.totalDistance) },
                        onBeginFinishHold: { vm.beginFinishHold(locationManager: locationManager) },
                        onEndFinishHold: { vm.cancelFinishHold() },
                        onTapMyLocation: { vm.tapCurrentLocation(locationManager: locationManager) },
                        onTapToggleCapturedArea: {
                            vm.toggleCapturedArea(
                                locationManager: locationManager,
                                records: runRecordStore.runRecords
                            )
                        },
                        isAreaActive: vm.isAreaActive
                    )
                    Spacer()
                }
            }
            
            if case .countingDown(let n) = vm.runPhase {
                CountdownOverlay(countdown: n)
            }
        }
        .task {
            vm.onTask(locationManager: locationManager)
        }
        .overlay {
            if vm.runPhase == .runResult {
                ZStack {
                    Color.gang_black_opacity
                        .ignoresSafeArea()

                    RunResultModalView(viewModel: vm, onComplete: { vm.dismissRunResult() })
                }
            }
        }
    }
}

#Preview("MainView") {
    let coordinator = AppCoordinator()
    let runRecordStore = RunRecordStore()
    let locationManager = LocationManager()
    let vm = MainViewModel()
    
    return MainView(vm: vm, locationManager: locationManager)
        .environmentObject(coordinator)
        .environmentObject(runRecordStore)
        .preferredColorScheme(.dark)
}
