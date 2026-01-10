//
//  RunResultModalViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/12/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

final class RunResultModalViewModel: ObservableObject {
    @Published var latestRecord: RunRecordModel?
    @Published var hasReward: Bool = false
    @Published var rewardQueue: [RewardType] = []
    @Published var showRewardQueue: Bool = false

    @Published var routeImageURL: URL?
    @Published var capturedValue: Int = 0
    @Published var duration: TimeInterval?
    @Published var distance: Double?
    @Published var calories: Double?

    private var runRecordVM: RunRecordService!
    private let minionService = MinionService()
    private let weaponService = WeaponService()
    
    private var currentUID: String? {
        Auth.auth().currentUser?.uid
    }
    private var db = Firestore.firestore()

    // MARK: - 서버에서 최신 1건 가져오기
    func loadRecentRunRecord() {
        getLatestRouteImage { [weak self] urlString in
            guard let self = self else { return }
            if let urlString = urlString, let url = URL(string: urlString) {
                DispatchQueue.main.async { self.routeImageURL = url }
            }
        }

        getLatestRunStats { [weak self] duration, distance, calories in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.duration = duration
                self.distance = distance
                self.calories = calories
            }
        }

        getLatestCapturedArea { [weak self] value in
            guard let self = self else { return }
            if let value = value {
                DispatchQueue.main.async { self.capturedValue = Int(value) }
            }
        }

        collectRewards()
    }
    
    func getLatestCapturedArea(completion: @escaping (Double?) -> Void) {
        guard let uid = currentUID else { return }
        db.collection("RunRecordModels").document(uid).collection("runRecords")
            .order(by: "start_time", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 최신 기록 불러오기 실패: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("❌ 기록 없음")
                    completion(nil)
                    return
                }
                
                let data = document.data()
                if let value = data["capturedAreaValue"] as? Double {
                    completion(value)
                } else if let valueInt = data["capturedAreaValue"] as? Int {
                    completion(Double(valueInt))
                } else {
                    print("❌ capturedAreaValue 타입 불일치")
                    completion(nil)
                }
            }
    }
    
    // 최신 경로 이미지 URL 로드
    func getLatestRouteImage(completion: @escaping (String?) -> Void) {
        guard let uid = currentUID else { return }
        db.collection("RunRecordModels").document(uid).collection("runRecords")
            .order(by: "start_time", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ routeImage 가져오기 실패: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let doc = snapshot?.documents.first else {
                    print("❌ 문서 없음")
                    completion(nil)
                    return
                }
                
                if let urlString = doc.data()["routeImage"] as? String {
                    print("✅ routeImage 가져옴: \(urlString)")
                    completion(urlString)
                } else {
                    print("❌ routeImage 필드 없음")
                    completion(nil)
                }
            }
    }
    
    // 최신 거리, 시간(여기서 계산), 칼로리(여기서 계산) 가져오기
    func getLatestRunStats(completion: @escaping (_ distance: Double, _ duration: TimeInterval, _ calories: Double) -> Void) {
        guard let uid = currentUID else { return }
        db.collection("RunRecordModels").document(uid).collection("runRecords")
            .order(by: "start_time", descending: true)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let document = snapshot?.documents.first else {
                    print("❌ 문서 없음 또는 오류: \(error?.localizedDescription ?? "")")
                    return
                }
                
                let data = document.data()
                
                guard let distance = data["distance"] as? Double,
                      let startTimestamp = data["start_time"] as? Timestamp,
                      let endTimestamp = data["end_time"] as? Timestamp else {
                    print("❌ 필요한 필드 누락 또는 타입 오류")
                    return
                }
                
                let start = startTimestamp.dateValue()
                let end = endTimestamp.dateValue()
                let duration = end.timeIntervalSince(start)
                let calories = duration / 60 * 7.4
                
                DispatchQueue.main.async {
                    self?.distance = distance
                    self?.duration = duration
                    self?.calories = calories
                    completion(distance, duration, calories)
                }
            }
    }

    private func collectRewards() {
        var collected: [RewardType] = []

        weaponService.checkWeaponUnlockOnStop { [weak self] unlocked in
            guard let self = self else { return }
            let weaponRewards = unlocked.map { RewardType.weapon($0) }
            collected.append(contentsOf: weaponRewards)
            print("해금된 무기: \(unlocked.map { $0.id })")

            self.minionService.checkMinionUnlockOnStop { [weak self] unlockedMinions in
                guard let self = self else { return }
                let minionRewards = unlockedMinions.map { RewardType.minion($0) }
                print("해금된 미니언: \(unlockedMinions.map { $0.id })")

                // 미니언을 앞으로
                collected.insert(contentsOf: minionRewards, at: 0)

                DispatchQueue.main.async {
                    if !collected.isEmpty {
                        self.rewardQueue = collected
                        self.hasReward = true
                    }
                }
            }
        }
    }

    var hasRewardQueue: Bool {
        !rewardQueue.isEmpty
    }
}
