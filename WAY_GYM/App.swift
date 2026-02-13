import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UIKit
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        application.registerForRemoteNotifications()
        return true
    }
    
    func application(
            _ application: UIApplication,
            didReceiveRemoteNotification userInfo: [AnyHashable : Any],
            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
        ) {
            if Auth.auth().canHandleNotification(userInfo) {
                completionHandler(.noData)
                return
            }
            completionHandler(.newData)
        }
}

@main
struct WAY_GYMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            RootView(moduleFactory: ModuleFactory.shared)
                .environmentObject(coordinator)
                .font(.text01)
                .foregroundColor(Color("gang_text_2"))
        }
    }
} 
