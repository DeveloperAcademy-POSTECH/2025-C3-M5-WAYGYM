import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UIKit
import FirebaseAuth

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
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var locationManager = LocationManager()
    // @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some Scene {
        WindowGroup {
            RootView(moduleFactory: ModuleFactory.shared)
                .environmentObject(coordinator)
                .font(.text01)
                .foregroundColor(Color("gang_text_2"))
        }
    }
} 
