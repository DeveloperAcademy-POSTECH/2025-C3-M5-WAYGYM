//
//  RunRecordModelsViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/4/25.
//
import Foundation
import Combine
import SwiftUI
import MapKit
import FirebaseAuth

class RunRecordStore: ObservableObject {
    @Published var runRecords: [RunRecordModel] = []
    @Published var totalDistance: Double = 0.0
    @Published var totalCapturedAreaValue: Int = 0
    
    // 무기(거리 보상) 계산 결과 캐시
    @Published var unlockedWeaponIds: Set<String> = []
    @Published var weaponAcquiredAtById: [String: Date] = [:]  // weaponId -> 획득일(첫 임계치 도달 시점)
    
    private let weaponModel = WeaponModel()
    private let runRecordRepository: RunRecordRepositoryProtocol

    init(runRecordRepository: RunRecordRepositoryProtocol = RunRecordRepository()) {
        self.runRecordRepository = runRecordRepository
    }
    
    // 앱 진입/런 종료 직후 등에 호출: 내 RunRecords를 1회 fetch 후 store 상태 갱신
    @MainActor
    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자가 없습니다. RunRecords refresh 중단")
            resetRunRecordStore()
            return
        }

        do {
            let records = try await runRecordRepository.fetchUserRunRecords(uid: uid)
            runRecords = records
            recomputeTotals() // totalDistance/totalCapturedAreaValue/unlockedWeaponIds/weaponAcquiredAtById 갱신
        } catch {
            print("⚠️ RunRecords fetch 실패: \(error.localizedDescription)")
        }
    }

    @MainActor
    func resetRunRecordStore() {
        runRecords = []
        totalDistance = 0
        totalCapturedAreaValue = 0
        unlockedWeaponIds = []
        weaponAcquiredAtById = [:]
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
}
