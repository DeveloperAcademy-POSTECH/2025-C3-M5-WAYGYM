//
//  MainViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/9/26.
//

import Foundation
import Combine
import CoreGraphics
import MapKit
import FirebaseAuth

final class MainViewModel: ObservableObject {
    @Published var runPhase: RunPhase = .root
    @Published var latestRunRecord: RunRecord?
    
    // 이번 런(방금 종료한 런)으로 새로 해금된 무기들 (weaponId)
    @Published var justUnlockedWeaponIds: [String] = []

    // 런 시작 직전까지의 누적 거리(m). 런 시작 시점에 저장해두고, 런 종료 후 보상 계산에 사용한다.
    private var runStartTotalDistanceM: Double = 0

    func clearJustUnlockedWeapons() {
        justUnlockedWeaponIds = []
    }

    /// 런이 "시작"되는 순간에 호출해서 기준 누적거리를 저장한다.
    /// - Parameter totalDistanceM: 런 시작 직전까지의 누적 거리(m)
    func markRunStart(totalDistanceM: Double) {
        runStartTotalDistanceM = totalDistanceM
        justUnlockedWeaponIds = []
        print("🎬 markRunStart | prevTotal(m)=\(runStartTotalDistanceM)")
    }
    
    private let runRecordRepository: RunRecordRepositoryProtocol

    init(runRecordRepository: RunRecordRepositoryProtocol = RunRecordRepository()) {
        self.runRecordRepository = runRecordRepository
    }
    @Published var isAreaActive: Bool = false
    private var backupPolylines: [MKPolyline] = []
    private var countdownTimer: Timer?
    private var finishHoldTimer: Timer?

    func onTask() {
        // 기본 상태로 리셋
        runPhase = .root
        isAreaActive = false
        backupPolylines.removeAll()
        // holdProgress = 0
    }

    
    // MARK: - 컨트롤 패널
    func tapCurrentLocation(locationManager: LocationManager) {
        locationManager.moveToCurrentLocation()
    }

    func toggleCapturedArea(locationManager: LocationManager, records: [RunRecord]) {
        isAreaActive.toggle()

        if isAreaActive {
            backupPolylines = locationManager.polylines
            locationManager.polylines.removeAll()
            locationManager.loadCapturedPolygons(from: records)
        } else {
            locationManager.polygons.removeAll()
            locationManager.polylines = backupPolylines
        }

        // 기존 LocationManager 플래그도 동기화(프로젝트 내 다른 곳에서 쓸 수 있으니)
        locationManager.isAreaActive = isAreaActive
    }
    
    // MARK: - 런닝 버튼
    func tapPlay(locationManager: LocationManager, currentTotalDistanceM: Double? = nil) {
        guard runPhase == .root else { return }
        if currentTotalDistanceM == nil {
            print("⚠️ tapPlay called without currentTotalDistanceM. runStartTotalDistanceM stays as \(runStartTotalDistanceM). 보상 계산이 어긋날 수 있어요.")
        }
        if let currentTotalDistanceM {
            markRunStart(totalDistanceM: currentTotalDistanceM)
        }
        countdownTimer?.invalidate()

        var remaining = 3
        runPhase = .countingDown(remaining)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            remaining -= 1

            if remaining <= 0 {
                timer.invalidate()
                self.countdownTimer = nil

                self.runPhase = .running
                locationManager.startSimulation()
            } else {
                self.runPhase = .countingDown(remaining)
            }
        }
    }

    func beginFinishHold(locationManager: LocationManager) {
        guard runPhase == .running else { return }

        runPhase = .finishing(progress: 0)

        finishHoldTimer?.invalidate()

        finishHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] timer in
            guard let self else { return }
            
            let current: CGFloat
            if case .finishing(let progress) = runPhase {
                current = progress
            } else {
                timer.invalidate()
                self.finishHoldTimer = nil
                return
            }
            let next = min(1.0, current + 0.03)
            self.runPhase = .finishing(progress: next)
            
            if next >= 1.0 {
                timer.invalidate()
                self.finishHoldTimer = nil
                locationManager.stopSimulation()
                self.runPhase = .runResult
            }
        }
    }

    // 정지 버튼을 끝까지 하지 않고 중간에 손을 뗐을 때
    func cancelFinishHold() {
        finishHoldTimer?.invalidate()
        finishHoldTimer = nil
        runPhase = .running
    }

    func dismissRunResult() {
        runPhase = .root
    }
}

// MARK: - 최신 런 결과 불러오기
extension MainViewModel {
    func loadLatestRunResult() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자가 없습니다. 최신 런 결과 조회 중단")
            return
        }

        Task {
            do {
                guard let latest = try await runRecordRepository.fetchLatestRunRecord(uid: uid) else {
                    print("❌ 최신 런닝 결과 문서 없음")
                    return
                }

                await MainActor.run {
                    self.latestRunRecord = latest

                    // "이번 런" 보상(새로 해금된 무기) 계산
                    self.justUnlockedWeaponIds = self.computeJustUnlockedWeaponIds(
                        prevTotalDistanceM: self.runStartTotalDistanceM,
                        addedDistanceM: latest.distanceM
                    )

                    let newTotal = self.runStartTotalDistanceM + latest.distanceM
                    print("🧾 latestRunResult | docId=\(latest.id ?? "(no id)") start=\(latest.startTime) end=\(String(describing: latest.endTime)) distanceM=\(latest.distanceM)")
                    print("🧮 rewardCalc input | prevTotalDistanceM=\(self.runStartTotalDistanceM) addedDistanceM=\(latest.distanceM) newTotalDistanceM=\(newTotal)")
                    print("🎁 justUnlockedWeaponIds=\(self.justUnlockedWeaponIds)")
                }
            } catch {
                print("❌ 최신 런닝 결과 불러오기 실패: \(error.localizedDescription)")
            }
        }
    }

    /// prevTotalDistanceM(런 시작 전 누적) + addedDistanceM(이번 런 거리)를 기준으로 "이번 런으로 새로" 해금된 무기 id를 계산
    private func computeJustUnlockedWeaponIds(prevTotalDistanceM: Double, addedDistanceM: Double) -> [String] {
        let weaponModel = WeaponModel()
        let newTotal = prevTotalDistanceM + addedDistanceM
        print("🧪 computeJustUnlockedWeaponIds | prev=\(prevTotalDistanceM) added=\(addedDistanceM) newTotal=\(newTotal)")

        // unlockNumber는 km 기준이므로 m로 변환
        let sorted = weaponModel.allWeapons.sorted { $0.unlockNumber < $1.unlockNumber }

        let ids = sorted.compactMap { w -> String? in
            let thresholdM = w.unlockNumber * 1000
            let crossed = (prevTotalDistanceM < thresholdM && newTotal >= thresholdM)
            if crossed {
                print("✅ crossed | weaponId=\(w.id) unlockNumber(km)=\(w.unlockNumber) thresholdM=\(thresholdM)")
                return w.id
            }
            return nil
        }

        return ids
    }
}
