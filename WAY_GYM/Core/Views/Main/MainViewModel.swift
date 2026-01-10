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

final class MainViewModel: ObservableObject {
    @Published var runPhase: RunPhase = .root
    
    @Published var isAreaActive: Bool = false
    private var backupPolylines: [MKPolyline] = []
    private var countdownTimer: Timer?
    private var finishHoldTimer: Timer?

    func onTask(locationManager: LocationManager) {
        locationManager.fetchRunRecordsFromFirestore()
        locationManager.moveToCurrentLocation()

        // 기본 상태로 리셋
        locationManager.isSimulating = false
        runPhase = .root
        isAreaActive = false
        backupPolylines.removeAll()
        // holdProgress = 0
    }

    // MARK: - ControlPanel
    func tapPlay(locationManager: LocationManager) {
        guard runPhase == .root else { return }
        startCountdown(locationManager: locationManager)
    }

    private func startCountdown(locationManager: LocationManager) {
        countdownTimer?.invalidate()

        var remaining = 3
        runPhase = .countingDown(remaining)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }
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
        // 결과 모달 닫기
        runPhase = .root
        // holdProgress = 0
    }

    func tapMyLocation(locationManager: LocationManager) {
        locationManager.moveToCurrentLocation()
    }

    func toggleCapturedArea(locationManager: LocationManager) {
        isAreaActive.toggle()

        if isAreaActive {
            backupPolylines = locationManager.polylines
            locationManager.polylines.removeAll()
            locationManager.loadCapturedPolygons(from: locationManager.runRecordList)
            // Firestore 리스너 재호출로 polylines 방지
            locationManager.fetchRunRecordsFromFirestore()
        } else {
            locationManager.polygons.removeAll()
            locationManager.polylines = backupPolylines
            locationManager.fetchRunRecordsFromFirestore()
        }

        // 기존 LocationManager 플래그도 동기화(프로젝트 내 다른 곳에서 쓸 수 있으니)
        locationManager.isAreaActive = isAreaActive
    }
}
