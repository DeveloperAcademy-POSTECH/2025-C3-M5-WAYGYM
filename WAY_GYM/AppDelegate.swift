//
//  AppDelegate.swift
//  WAY_GYM
//
//  Created by Leo on 6/2/25.
//

import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        print("FirebaseApp.configure() 호출 완료")
        
        //Firebase 연결 확인 예제 코드
        do {
            let auth = Auth.auth()
            print("Firebase 인스턴스를 성공적으로 불러옴")
        } catch let error {
            print("연결확인중 오류 발생: \(error.localizedDescription)")
        }
        
        return true
    }
}
