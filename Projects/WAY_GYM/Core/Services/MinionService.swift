//
//  MinionUseCase.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/12/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

final class MinionService: ObservableObject {
    private var db = Firestore.firestore()
    @Published var totalDistance: Double = 0.0

    // 뷰에서 관찰할 상태들
    @Published var acquiredMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []

    // 내부 의존성 (런 기록)
    let runRecordService: RunRecordService
    private let minionModel = MinionModel()

    // MARK: - Init
    init(runRecordVM: RunRecordService = RunRecordService()) {
        self.runRecordService = runRecordVM
        minionModel.loadMinionsDB()
    }
    
    // MARK: - Unlock 기준 (km → m 변환 비교)
    func isUnlocked(_ minion: MinionDefinitionModel, with distanceValue: Int) -> Bool {
        return Double(distanceValue) >= minion.unlockNumber * 1000
    }

    // MARK: - 획득 날짜 계산(스마트)
    // 미니언 리스트 뷰, 미니언 싱글 뷰에서 사용
    /// 1) 로컬 runRecords가 있으면 즉시 계산
    /// 2) 없으면 Firestore에서 최신 기록을 불러와 계산
    /// - Note: unlockNumber는 km 단위이므로 m(미터)로 변환해서 비교
    func acquisitionDateSmart(for minion: MinionDefinitionModel, completion: @escaping (Date?) -> Void) {
        let unlockInMeters = minion.unlockNumber * 1000

        // 1) 로컬 캐시 사용
        let localRecords = runRecordService.runRecords
        if !localRecords.isEmpty {
            let sorted = localRecords.sorted { $0.startTime < $1.startTime }
            var cumulative: Double = 0
            for record in sorted {
                cumulative += record.distance
                if cumulative >= unlockInMeters {
                    completion(record.startTime)
                    return
                }
            }
            completion(nil)
            return
        }

        // 2) 서버에서 최신 기록 로드(Firestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자 UID를 가져올 수 없습니다.")
            completion(nil)
            return
        }
        let db = Firestore.firestore()
        db.collection("RunRecordModels").document(uid).collection("runRecords")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 기록 불러오기 실패: \(error?.localizedDescription ?? "")")
                    completion(nil)
                    return
                }

                let records: [(distance: Double, startTime: Date)] = documents.compactMap { doc in
                    let data = doc.data()
                    guard let startTs = data["start_time"] as? Timestamp else { return nil }
                    let start = startTs.dateValue()

                    if let dist = data["distance"] as? Double {
                        return (dist, start)
                    } else if let distInt = data["distance"] as? Int {
                        return (Double(distInt), start)
                    } else {
                        return nil
                    }
                }

                let sorted = records.sorted { $0.startTime < $1.startTime }
                var cumulative: Double = 0
                for r in sorted {
                    cumulative += r.distance
                    if cumulative >= unlockInMeters {
                        completion(r.startTime)
                        return
                    }
                }
                completion(nil)
            }
    }

    // MARK: - 런닝 직후: 새로 획득한 미니언 확인
    func checkMinionUnlockOnStop(completion: @escaping ([MinionDefinitionModel]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자 UID를 가져올 수 없습니다.")
            completion([])
            return
        }
        let db = Firestore.firestore()
        db.collection("RunRecordModels").document(uid).collection("runRecords")
            .getDocuments { snapshot, error in
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

                for minion in MinionModel.allMinions {
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

    // MARK: - 최근 획득 미니언 (프로필용): 총 누적 거리 기반
    // 미니언 리스트 뷰, 프로필 미니언 뷰에서 사용
    func fetchRecentUnlockedMinions(runRecordVM runRecordService: RunRecordService,
                                    completion: @escaping ([(minion: MinionDefinitionModel, acquisitionDate: Date)]) -> Void) {
        runRecordService.getTotalDistanceForRewards { total in
            let unlockedMinions = MinionModel.allMinions.filter {
                self.isUnlocked($0, with: Int(total ?? 0))
            }
            let sorted = unlockedMinions
                .sorted { Int($0.id) ?? 0 < Int($1.id) ?? 0 }
                .suffix(3)
            let result = sorted.map { (minion: $0, acquisitionDate: Date()) }
            completion(result)
        }
    }

    // 기존 함수 재사용: suffix(3) 제거 + 내부 runRecordVM 사용
    // 프로필 미니언 뷰에서 사용
    func fetchRecentUnlockedMinions() {
        runRecordService.getTotalDistanceForRewards { total in
            let unlocked = MinionModel.allMinions.filter {
                self.isUnlocked($0, with: Int(total ?? 0))
            }
            // 정렬 기준을 unlockNumber(요구 km) 오름차순으로 정렬
            let sorted = unlocked.sorted { $0.unlockNumber < $1.unlockNumber }
            let result = sorted.map { (minion: $0, acquisitionDate: Date()) }

            DispatchQueue.main.async {
                self.acquiredMinions = result
            }
        }
    }

}
