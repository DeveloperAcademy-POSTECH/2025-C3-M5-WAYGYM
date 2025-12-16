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
    
    // 전화번호 가입 관련 함수
    func application(_ application: UIApplication,
                         didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // FirebaseAuth가 처리해야 하는 푸시 알림이면 여기서 핸들링
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        // 만약 다른 알림 로직 있으면 여기서 처리 (없으면 아래 코드는 유지)
        completionHandler(.newData)
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
            RootView()
                .environmentObject(router)
        }
    }
} 
