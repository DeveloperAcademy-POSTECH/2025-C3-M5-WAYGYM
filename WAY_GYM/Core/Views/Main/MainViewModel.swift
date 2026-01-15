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
import FirebaseFirestore
import FirebaseFirestoreSwift

final class MainViewModel: ObservableObject {
    @Published var runPhase: RunPhase = .root
    
    @Published var latestRunRecord: RunRecordModels?
    private let db = Firestore.firestore()
    
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

// MARK: - 최신 런 결과 불러오기
extension MainViewModel {
    func loadLatestRunResult() {
        db.collection("RunRecordModels")
            .order(by: "start_time", descending: true)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ 최신 런닝 결과 불러오기 실패: \(error.localizedDescription)")
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    print("❌ 최신 런닝 결과 문서 없음")
                    return
                }

                // 1) UI를 빠르게 띄우기: 문서에서 요약 필드만 뽑아 "가벼운 RunRecordModels"를 먼저 세팅
                let data = doc.data()

                let distance: Double = {
                    if let d = data["distance"] as? Double { return d }
                    if let i = data["distance"] as? Int { return Double(i) }
                    return 0
                }()

                let startTime: Date = {
                    if let ts = data["start_time"] as? Timestamp { return ts.dateValue() }
                    if let date = data["start_time"] as? Date { return date }
                    return Date()
                }()

                let endTime: Date? = {
                    if let ts = data["end_time"] as? Timestamp { return ts.dateValue() }
                    if let date = data["end_time"] as? Date { return date }
                    return nil
                }()

                let routeImage: String? = {
                    if let s = data["routeImage"] as? String { return s }
                    return nil
                }()

                let capturedAreaValue: Int = {
                    if let v = data["capturedAreaValue"] as? Int { return v }
                    if let d = data["capturedAreaValue"] as? Double { return Int(d) }
                    return 0
                }()

                // 좌표/면적 그룹은 비어있는 상태로 먼저 넣어 UI 표시 속도를 확보
                let lightweight = RunRecordModels(
                    id: doc.documentID,
                    distance: distance,
                    startTime: startTime,
                    endTime: endTime,
                    routeImage: routeImage,
                    coordinates: [],
                    capturedAreas: [],
                    capturedAreaValue: capturedAreaValue,
                    capturedCellIds: []
                )

                DispatchQueue.main.async {
                    self?.latestRunRecord = lightweight
                    print("⚡️ 요약 필드로 먼저 표시: \(doc.documentID)")
                }

                // 2) 백그라운드에서 전체 디코딩(좌표 포함) 후 최신값으로 교체
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let fullRecord = try doc.data(as: RunRecordModels.self)
                        DispatchQueue.main.async {
                            self?.latestRunRecord = fullRecord
                            print("✅ 전체 디코딩 완료: \(fullRecord.id ?? "(no id)")")
                        }
                    } catch {
                        print("❌ RunRecordModels 전체 디코딩 실패: \(error)")
                    }
                }
            }
    }
}
