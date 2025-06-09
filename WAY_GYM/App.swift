import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UIKit
import FirebaseAuth


//class AppDelegate: NSObject, UIApplicationDelegate {
//    func application(_ application: UIApplication,
//                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
//        FirebaseApp.configure()
//        return true
//    }
//}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase 초기화 완료")
        return true
    }
}

@main
struct WAY_GYMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var router = AppRouter()
    @StateObject private var locationManager = LocationManager()
    // @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some Scene {
        WindowGroup {
            // RootView()
            
            RunResultTestView()
                .environmentObject(router)
            
//            RunResultModalView(
//                onComplete: {
//                    print("구역 확장 결과 모달 버튼 클릭")
//                }
//                // hasReward: true
//            )
//            .environmentObject(RunRecordViewModel())
            
//            ProfileView()
//                .environmentObject(router)
//                .environmentObject(MinionViewModel())
//                .environmentObject(WeaponViewModel())
//                .environmentObject(RunRecordViewModel())
//                .font(.text01)
//                .foregroundColor(Color("gang_text_2"))
        }
    }
} 
