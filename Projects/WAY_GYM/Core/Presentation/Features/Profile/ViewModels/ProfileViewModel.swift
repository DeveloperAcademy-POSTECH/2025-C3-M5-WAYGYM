//
//  ProfileViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/12/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

final class ProfileViewModel: ObservableObject {
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    private let minionService = MinionService()
    private let runRecordService = RunRecordService()
    
    var totalCapturedAreaValue: Int = 0
    var mainWeaponImageName: String {
        return "main_\(selectedWeaponId)"
    }
    var weaponIconImageName: String {
        return "weapon_\(selectedWeaponId)"
    }
    
    func load() {
        runRecordService.getTotalDistanceForRewards { [weak self] _ in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
        getTotalCapturedArea()
        DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() }
    }
    
    private var db = Firestore.firestore()
    // 서버에서 총 딴 면적 가져오기
    func getTotalCapturedArea() {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자 UID를 가져올 수 없습니다.")
            self.totalCapturedAreaValue = 0
            return
        }
        
        db.collection("RunRecordModels").document(uid).collection("runRecords")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 런닝 딴 땅 불러오기 실패: \(error?.localizedDescription ?? "")")
                    return
                }
                
                let areas = documents.compactMap { doc -> Int? in
                    if let value = doc.data()["capturedAreaValue"] as? Int {
                        return value
                    } else if let valueDouble = doc.data()["capturedAreaValue"] as? Double {
                        // 혹시 Double로 저장된 경우 Int로 변환
                        let intValue = Int(valueDouble)
                        print("✅ 총 area 값 (Double->Int 변환): \(intValue)")
                        return intValue
                    } else {
                        print("⚠️ area 없음 또는 타입 불일치")
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    self?.totalCapturedAreaValue = areas.reduce(0, +)
                    print("🎯 총 딴 땅 계산 완료: \(self?.totalCapturedAreaValue ?? 0)")
                }
            }
    }

    var totalCapturedAreaText: String { "\(totalCapturedAreaValue)m²" }
    var totalDistanceKmText: String { "\(formatDecimal2(runRecordService.totalDistance / 1000)) km" }

    var hasUnlockedMinions: Bool {
        let unlocked = MinionModel.allMinions.filter { minion in
            return minionService.isUnlocked(minion, with: Int(runRecordService.totalDistance))
        }
        return !unlocked.isEmpty
    }

    var hasRunRecords: Bool { runRecordService.totalDistance > 0 }
}
