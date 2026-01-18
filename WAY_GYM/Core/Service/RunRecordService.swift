//
//  RunRecordModelsViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/4/25.
//
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine
import SwiftUI
import MapKit
import FirebaseAuth

class RunRecordService: ObservableObject {
    @Published var runRecords: [RunRecordModel] = []
    @Published var totalDistance: Double = 0.0
    @Published var totalCapturedAreaValue: Int = 0
    
    // 무기(거리 보상) 계산 결과 캐시
    @Published var unlockedWeaponIds: Set<String> = []
    @Published var weaponAcquiredAtById: [String: Date] = [:]  // weaponId -> 획득일(첫 임계치 도달 시점)
    
    // 이번 스냅샷(=이번 런 반영)으로 "새로" 해금된 무기들
    @Published var newlyUnlockedWeaponIds: [String] = []

    /// RunResultModal 등에서 소비한 뒤 호출해서 큐를 비운다
    func clearNewlyUnlockedWeapons() {
        newlyUnlockedWeaponIds = []
    }
    
    private let weaponModel = WeaponModel()
    
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // 앱 접속 시 1회 호출: 내 RunRecords를 계속 동기화
    func startListeningUserRunRecords() {
        listener?.remove()

        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자가 없습니다. RunRecords listen 중단")
            DispatchQueue.main.async {
                self.runRecords = []
                self.totalDistance = 0
                self.totalCapturedAreaValue = 0
                self.unlockedWeaponIds = []
                self.weaponAcquiredAtById = [:]
                self.newlyUnlockedWeaponIds = []
            }
            return
        }

        listener = db.collection("RunRecords")
            .document(uid)
            .collection("runs")
            .order(by: "start_time", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("⚠️ RunRecords listen 실패: \(error.localizedDescription)")
                    return
                }

                let docs = snapshot?.documents ?? []
                let records: [RunRecordModel] = docs.compactMap { doc -> RunRecordModel? in
                    let data = doc.data()

                    // --- 필수 필드 파싱 ---
                    guard let startTS = data["start_time"] as? Timestamp else { return nil }
                    let startTime = startTS.dateValue()

                    let endTime: Date? = {
                        if let ts = data["end_time"] as? Timestamp { return ts.dateValue() }
                        return nil
                    }()

                    let distanceM: Double = {
                        if let d = data["distance_m"] as? Double { return d }
                        if let i = data["distance_m"] as? Int { return Double(i) }
                        return 0
                    }()

                    let routeEncoded = (data["route_encoded"] as? String) ?? ""

                    let capturedCellIds: [String] = {
                        if let arr = data["captured_cell_ids"] as? [String] { return arr }
                        return []
                    }()

                    let routeFrame: [Double] = {
                        if let arr = data["route_frame"] as? [Double] { return arr }
                        if let arr = data["route_frame"] as? [NSNumber] { return arr.map { $0.doubleValue } }
                        return [0, 0, 0, 0]
                    }()

                    // ⚠️ RunRecordModel이 단일 모델로 통합되었다는 전제
                    return RunRecordModel(
                        id: doc.documentID,
                        startTime: startTime,
                        endTime: endTime,
                        distanceM: distanceM,
                        routeEncoded: routeEncoded,
                        capturedCellIds: capturedCellIds,
                        routeFrame: routeFrame
                    )
                }

                // 스냅샷 반영 전 상태(이전까지 해금된 무기) 스냅샷
                let prevUnlocked = self.unlockedWeaponIds

                DispatchQueue.main.async {
                    self.runRecords = records
                    self.recomputeTotals() // 여기서 unlockedWeaponIds/weaponAcquiredAtById가 갱신됨

                    // 이번 업데이트로 새로 해금된 무기들(diff)
                    let diff = self.unlockedWeaponIds.subtracting(prevUnlocked)
                    if !diff.isEmpty {
                        // 정렬: unlockNumber 오름차순 기준으로 보여주기 좋게
                        let order = self.weaponModel.allWeapons
                            .sorted { $0.unlockNumber < $1.unlockNumber }
                            .map { $0.id }

                        self.newlyUnlockedWeaponIds = diff
                            .sorted { (a, b) in
                                (order.firstIndex(of: a) ?? Int.max) < (order.firstIndex(of: b) ?? Int.max)
                            }
                    } else {
                        self.newlyUnlockedWeaponIds = []
                    }
                }
            }
    }

    func recomputeTotals() {
        // 총 달린 거리: meter 합
        totalDistance = runRecords.map { $0.distanceM }.reduce(0, +)
        
        // 총 딴 면적: "현재"의 소유 셀 기준으로 따로 관리할 예정이면 여기서 계산하지 말고,
        // 우선은 "기록들 capturedCellIds 합집합"을 기준으로 임시 계산한다.
        // (셀 1칸 = 100m²)
        var allCellIds: Set<String> = []
        for r in runRecords {
            allCellIds.formUnion(r.capturedCellIds)
        }
        totalCapturedAreaValue = allCellIds.count * 100
        recomputeWeaponUnlocks()
    }
    
    // 무기(거리 보상): runRecords를 기반으로 "획득한 무기"와 "획득일"을 미리 계산해 캐시
    // - 획득일: 누적 거리가 해당 무기의 unlock 임계치를 "처음" 넘은 런의 startTime
    private func recomputeWeaponUnlocks() {
        let recordsAsc = runRecords.sorted { $0.startTime < $1.startTime }

        // unlockNumber는 km 기준이므로 m로 변환
        let weaponsAsc = weaponModel.allWeapons
            .sorted { $0.unlockNumber < $1.unlockNumber }
            .map { (id: $0.id, unlockM: $0.unlockNumber * 1000) }

        var newUnlocked: Set<String> = []
        var newAcquiredAt: [String: Date] = [:]

        var cumulativeM: Double = 0
        var wIndex = 0

        for r in recordsAsc {
            cumulativeM += r.distanceM

            // 현재 누적 거리로 새로 unlock되는 무기들을 모두 처리
            while wIndex < weaponsAsc.count, cumulativeM >= weaponsAsc[wIndex].unlockM {
                let weaponId = weaponsAsc[wIndex].id
                newUnlocked.insert(weaponId)

                // 획득일은 "처음" unlock된 시점만 기록
                if newAcquiredAt[weaponId] == nil {
                    newAcquiredAt[weaponId] = r.startTime
                }

                wIndex += 1
            }

            if wIndex >= weaponsAsc.count { break }
        }

        unlockedWeaponIds = newUnlocked
        weaponAcquiredAtById = newAcquiredAt
    }
    
    // 미니언(듀오 승리 보상으로 변경 예정): 일단 기존 로직 유지(거리 기반) — 추후 교체 필요
    func fetchRunRecordsAndCalculateMinionAcquisitionDate(for unlockNumber: Double, completion: @escaping (Date?) -> Void) {
        // unlockNumber: km
        let unlockM = unlockNumber * 1000

        let sorted = runRecords.sorted { $0.startTime < $1.startTime }
        var cumulativeM: Double = 0

        var acquisitionDate: Date? = nil
        for r in sorted {
            cumulativeM += r.distanceM
            if cumulativeM >= unlockM {
                acquisitionDate = r.startTime
                break
            }
        }

        completion(acquisitionDate)
    }
    
    deinit {
        listener?.remove()
    }
}
