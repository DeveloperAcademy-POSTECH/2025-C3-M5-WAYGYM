//
//  WeaponViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/12/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

final class WeaponService: ObservableObject {
    @Published var currentRewardWeapon: WeaponDefinitionModel? = nil
    @Published var runRecordVM = RunRecordService()
    @Published var weaponModel = WeaponModel()
    
    var allWeapons: [WeaponDefinitionModel] {
        weaponModel.allWeapons
    }
    
    private var db = Firestore.firestore()
    
    // 런닝 직후 - 새로 획득한 무기 확인 함수
    func checkWeaponUnlockOnStop(completion: @escaping ([WeaponDefinitionModel]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자 UID를 가져올 수 없습니다.")
            completion([])
            return
        }
        
        // 최신 기록 포함한 모든 런닝 기록 가져옴
        db.collection("RunRecordModels").document(uid).collection("runRecords")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 기록 불러오기 실패: \(error?.localizedDescription ?? "")")
                    completion([])
                    return
                }

                let records: [(capturedAreaValue: Double, startTime: Timestamp)] = documents.compactMap { doc in
                    let data = doc.data()
                    guard let capturedAreaValue = data["capturedAreaValue"] as? Double,
                          let startTime = data["start_time"] as? Timestamp else {
                        print("⚠️ 데이터 누락 또는 타입 불일치 in \(doc.documentID)")
                        return nil
                    }
                    return (capturedAreaValue, startTime)
                }

                let sorted = records.sorted { $0.startTime.dateValue() > $1.startTime.dateValue() }
                
                guard let latestRecord = sorted.first else {
                    print("⚠️ 기록 없음")
                    completion([])
                    return
                }

                let currentTotal = records.map { $0.capturedAreaValue }.reduce(0, +)
                let prevTotal = currentTotal - latestRecord.capturedAreaValue

                print("면적 📊 총: \(currentTotal), 총-최신 기록: \(prevTotal)")

                var newlyUnlockedWeapons: [WeaponDefinitionModel] = []

                for weapon in self?.allWeapons ?? [] {
                    let unlock = weapon.unlockNumber
                    print("🧪 무기 \(weapon.id): unlockNumber = \(unlock)")
                    print("🧪 비교: prevTotal=\(prevTotal), currentTotal=\(currentTotal)")

                    let wasLockedBefore = Int(prevTotal) < Int(unlock)
                    let isUnlockedNow = Int(currentTotal) >= Int(unlock)

                    print("🧪 \(weapon.id) → wasLockedBefore: \(wasLockedBefore), isUnlockedNow: \(isUnlockedNow)")

                    if wasLockedBefore && isUnlockedNow {
                        newlyUnlockedWeapons.append(weapon)
                    }
                }

                completion(newlyUnlockedWeapons)
            }
    }
}
