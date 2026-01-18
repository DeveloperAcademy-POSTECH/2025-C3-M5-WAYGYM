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
    @EnvironmentObject var runRecordService: RunRecordStore
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
            
            // 내 나와바리 이동 버튼
            if vm.runPhase == .root {
                HStack{
                    VStack(spacing: 6) {
                        Button {
                            coordinator.push(.profile)
                        } label: {
                            Image("ProfilIcon")
                                .resizable()
                                .frame(width: 40, height: 40)
                        }
                        Text("내 나와바리")
                            .font(.text02)
                            .foregroundColor(.white)
                        Spacer()
                        
                    }
                    Spacer()
                }
                .padding(20)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                VStack {
                    ControlPanel(
                        runPhase: vm.runPhase,
                        onTapStartRun: {
                            vm.tapPlay(locationManager: locationManager, currentTotalDistanceM: runRecordService.totalDistance) },
                        onBeginFinishHold: { vm.beginFinishHold(locationManager: locationManager) },
                        onEndFinishHold: { vm.cancelFinishHold() },
                        onTapMyLocation: { vm.tapMyLocation(locationManager: locationManager) },
                        onTapToggleCapturedArea: {
                            vm.toggleCapturedArea(
                                locationManager: locationManager,
                                records: runRecordService.runRecords
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
