//
//  MinionSingleViewModel.swift
//  Ch3Personal
//
//  Created by 이주현 on 6/1/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

final class MinionViewModel: ObservableObject {
    @Published var allMinions: [MinionDefinitionModel] = []
    @Published var selectedMinion: MinionDefinitionModel? = nil
    @Published var currentRewardMinion: MinionDefinitionModel? = nil
    
    private var minionModel = MinionModel()
       init() {
           self.allMinions = minionModel.allMinions
       }
    
    func isUnlocked(_ minion: MinionDefinitionModel, with distanceValue: Int) -> Bool {
        return Double(distanceValue) >= minion.unlockNumber * 1000
    }

    func acquisitionDate(for minion: MinionDefinitionModel) -> Date? {
        let sorted = runRecordVM.runRecords.sorted { $0.startTime < $1.startTime }
        var cumulative: Double = 0

        for record in sorted {
            cumulative += record.distance
            if cumulative >= minion.unlockNumber * 1000 {
                return record.startTime
            }
        }
        return nil
    }
    
    // 새로 획득한 미니언 확인 함수
    func checkMinionUnlockOnStop(completion: @escaping ([MinionDefinitionModel]) -> Void) {
        let db = Firestore.firestore()
        db.collection("RunRecordModels")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 기록 불러오기 실패: \(error?.localizedDescription ?? "")")
                    completion([])
                    return
                }

                let records: [(distance: Double, startTime: Timestamp)] = documents.compactMap { doc in
                    let data = doc.data()
                    guard let distance = data["distance"] as? Double,
                          let startTime = data["start_time"] as? Timestamp else {
                        print("⚠️ 데이터 누락 또는 타입 불일치 in \(doc.documentID)")
                        return nil
                    }
                    return (distance, startTime)
                }

                let sorted = records.sorted { $0.startTime.dateValue() > $1.startTime.dateValue() }

                guard let latestRecord = sorted.first else {
                    print("⚠️ 기록 없음")
                    completion([])
                    return
                }

                let currentTotal = records.map { $0.distance }.reduce(0, +)
                let prevTotal = currentTotal - latestRecord.distance

                print("거리 📏 총: \(currentTotal), 총-최신 기록: \(prevTotal)")

                var newlyUnlockedMinions: [MinionDefinitionModel] = []

                for minion in self?.allMinions ?? [] {
                    let unlock = minion.unlockNumber * 1000

                    let wasLockedBefore = prevTotal < unlock
                    let isUnlockedNow = currentTotal >= unlock

                    if wasLockedBefore && isUnlockedNow {
                        newlyUnlockedMinions.append(minion)
                    }
                }

                completion(newlyUnlockedMinions)
            }
    }
    
}

final class WeaponViewModel: ObservableObject {
    // @Published var allWeapons: [WeaponDefinitionModel] = []
    @Published var currentRewardWeapon: WeaponDefinitionModel? = nil
    @StateObject private var runRecordVM = RunRecordViewModel()
    
    @Published var weaponModel = WeaponModel()
    var allWeapons: [WeaponDefinitionModel] {
            weaponModel.allWeapons
        }

    // 총 면적과 무기 해금 조건 비교 함수
    func totalCaptureArea() -> Double {
        Double(runRecordVM.runRecords.map { $0.capturedAreaValue }.reduce(0, +))
    }

    func isUnlocked(_ weapon: WeaponDefinitionModel, with areaValue: Int) -> Bool {
        return Double(areaValue) >= weapon.unlockNumber
    }

    // 무기 얻은 날짜 계산 함수
    func acquisitionDate(for weapon: WeaponDefinitionModel, from records: [RunRecordModels]) -> Date? {
        let sorted = records.sorted { $0.startTime < $1.startTime }
        var cumulative: Double = 0

        for record in sorted {
            cumulative += Double(record.capturedAreaValue)
            if cumulative >= weapon.unlockNumber {
                return record.startTime
            }
        }
        return nil
    }
    
    private var db = Firestore.firestore()
    
    // 새로 획득한 무기 확인 함수
    func checkWeaponUnlockOnStop(completion: @escaping ([WeaponDefinitionModel]) -> Void) {
        // 최신 기록 포함한 모든 런닝 기록 가져옴
        db.collection("RunRecordModels")
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
