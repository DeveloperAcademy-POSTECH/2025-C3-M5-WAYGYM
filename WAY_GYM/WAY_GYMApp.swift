//
//  WAY_GYMApp.swift
//  WAY_GYM
//
//  Created by Leo on 5/27/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

//class Application: NSObject, UIApplicationDelegate {
//    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        FirebaseApp.configure()
////        print("FirebaseApp.configure() 호출 완료")
////        
////        //Firebase 연결 확인 예제 콛
////        do {
////            let auth = Auth.auth()
////            print("Firebase 인스턴스를 성공적으로 불러옴)")
////            
////        } catch let error {
////            print("연결확인중 오류 발생")
////        }
//        return true
//    }
//}

@main
struct WAY_GYMApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
//            ProfileView() // 쥬디제이꺼 보기
//                .environmentObject(MinionViewModel())
//                .environmentObject(WeaponViewModel())
                ContentView() // 레오꺼 보기
        }
    }
}
