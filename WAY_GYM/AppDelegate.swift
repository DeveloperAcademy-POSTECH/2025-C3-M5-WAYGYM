//
//  AppDelegate.swift
//  WAY_GYM
//
//  Created by Leo on 6/2/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase 초기화는 FirebaseAuth를 통해 자동으로 이루어집니다
        print("Firebase 초기화 완료")
        
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
