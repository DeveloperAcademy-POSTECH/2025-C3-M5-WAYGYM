import SwiftUI
import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import FirebaseCore

struct MainView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject var viewModel: MainViewModel
    
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    
    @ObservedObject var locationManager: LocationManager
    @StateObject private var runRecordService = RunRecordService()
    @StateObject private var weaponService = WeaponService()
    
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
            if viewModel.runPhase == .root {
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
                        runPhase: viewModel.runPhase,
                        onTapStartRun: { viewModel.tapPlay(locationManager: locationManager) },
                        onBeginFinishHold: { viewModel.beginFinishHold(locationManager: locationManager) },
                        onEndFinishHold: { viewModel.cancelFinishHold() },
                        onTapMyLocation: { viewModel.tapMyLocation(locationManager: locationManager) },
                        onTapToggleCapturedArea: { viewModel.toggleCapturedArea(locationManager: locationManager) },
                        isAreaActive: viewModel.isAreaActive
                    )
                    Spacer()
                }
            }
            
            if case .countingDown(let n) = viewModel.runPhase {
                CountdownOverlay(countdown: n)
            }
        }
        .task {
            viewModel.onTask(locationManager: locationManager)
        }
        .overlay {
            if viewModel.runPhase == .runResult {
                ZStack {
                    Color.gang_black_opacity
                        .ignoresSafeArea()

                    RunResultModalView(onComplete: { viewModel.dismissRunResult() })
                        .environmentObject(runRecordService)
                        .environmentObject(weaponService)
                }
            }
        }
    }
}
