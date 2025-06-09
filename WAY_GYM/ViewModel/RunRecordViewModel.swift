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

class RunRecordViewModel: ObservableObject {
    @Published var runRecords: [RunRecordModels] = []
    
    @Published var totalDistance: Double = 0.0
    @Published var totalCapturedAreaValue: Int = 0
    
    @Published var distance: Double?
    @Published var duration: TimeInterval?
     @Published var calories: Double?
    
    private var db = Firestore.firestore()
    
    // 서버에서 런닝 기록 가져오기
    func fetchRunRecordsFromFirestore() {
        db.collection("RunRecordModels")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("⚠️ 런닝 기록 불러오기 실패: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ 서버에 RunRecordsModels 기록 없음")
                    return
                }
                
                self?.runRecords = documents.compactMap { document in
                    try? document.data(as: RunRecordModels.self)
                }
                print("✅ runRecords 개수: \(self?.runRecords.count ?? 0)")
            }
    }

// MARK: - 지도 오버레이 생성
func makePolylines(from coordinates: [CoordinatePair]) -> [MKPolyline] {
    guard coordinates.count >= 2 else { return [] }

    let locationCoords = coordinates.map {
        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
    }
    let polyline = MKPolyline(coordinates: locationCoords, count: locationCoords.count)
    return [polyline]
}

func makePolygons(from areas: [CoordinatePairWithGroup]) -> [MKPolygon] {
    let grouped = Dictionary(grouping: areas, by: { $0.groupId })

    return grouped.values.compactMap { group in
        let coords = group.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        return MKPolygon(coordinates: coords, count: coords.count)
    }
}
    
    // 서버에서 달린 거리의 합 가져오기
    func fetchAndSumDistances() {
        db.collection("RunRecordModels")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 런닝 총거리 불러오기 실패: \(error?.localizedDescription ?? "")")
                    return
                }

                // distance만 직접 추출
                let distances = documents.compactMap { doc -> Double? in
                    if let value = doc.data()["distance"] as? Double {
                        return value
                    } else {
                        print("⚠️ distance 없음 또는 타입 불일치")
                        return nil
                    }
                }

                DispatchQueue.main.async {
                    self?.totalDistance = distances.reduce(0, +)
                    print("🎯 총 달린 거리 계산 완료: \(self?.totalDistance ?? 0)")
                }
            }
    }
    
    // 서버에서 총 딴 면적 가져오기
    func fetchAndSumCapturedValue() {
        db.collection("RunRecordModels")
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
    
    // 무기 얻은 날짜 구하기
    func fetchRunRecordsAndCalculateWeaponAcquisitionDate(for unlockNumber: Double, completion: @escaping (Date?) -> Void) {
        db.collection("RunRecordModels")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 런닝 기록 불러오기 실패: \(error?.localizedDescription ?? "")")
                    completion(nil)
                    return
                }

                let records: [(Date, Int)] = documents.compactMap { doc in
                    let data = doc.data()

                    guard let timestamp = data["start_time"] as? Timestamp else {
                        print("⚠️ start_time 누락 또는 타입 오류")
                        return nil
                    }
                    let startTime = timestamp.dateValue()

                    if let value = data["capturedAreaValue"] as? Int {
                        return (startTime, value)
                    } else if let valueDouble = data["capturedAreaValue"] as? Double {
                        return (startTime, Int(valueDouble))
                    } else {
                        print("⚠️ capturedAreaValue 누락 또는 타입 오류")
                        return nil
                    }
                }
                print("🔍 불러온 기록 개수: \(records.count)")

                let sortedRecords = records.sorted { $0.0 < $1.0 }

                var cumulative: Double = 0
                var acquisitionDate: Date? = nil
                for (startTime, areaValue) in sortedRecords {
                    cumulative += Double(areaValue)
                    print("누적 면적: \(cumulative), 현재 조건: \(unlockNumber)")
                    if cumulative >= unlockNumber {
                        acquisitionDate = startTime
                        print("획득 날짜 발견: \(acquisitionDate!)")
                        break
                    }
                }

                DispatchQueue.main.async {
                    completion(acquisitionDate)
                }
            }
    }
    
    // 미니언 얻은 날짜 구하기
    func fetchRunRecordsAndCalculateMinionAcquisitionDate(for unlockNumber: Double, completion: @escaping (Date?) -> Void) {
        db.collection("RunRecordModels")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 런닝 기록 불러오기 실패: \(error?.localizedDescription ?? "")")
                    completion(nil)
                    return
                }

                let records: [(Date, Double)] = documents.compactMap { doc in
                    let data = doc.data()

                    guard let timestamp = data["start_time"] as? Timestamp else {
                        print("⚠️ start_time 누락 또는 타입 오류")
                        return nil
                    }
                    let startTime = timestamp.dateValue()

                    if let value = data["distance"] as? Double {
                        return (startTime, value)
                    } else if let valueInt = data["distance"] as? Int {
                        return (startTime, Double(valueInt))
                    } else {
                        print("⚠️ distance 누락 또는 타입 오류")
                        return nil
                    }
                }

                let unlockNumberInMeters = unlockNumber * 1000
                let sortedRecords = records.sorted { $0.0 < $1.0 }
//                for (index, record) in sortedRecords.enumerated() {
//                    print("👉 [\(index)] 날짜: \(record.0), 거리: \(record.1)")
//                }

                var cumulative: Double = 0
                var acquisitionDate: Date? = nil
                for (startTime, distanceValue) in sortedRecords {
                    cumulative += distanceValue
                    
                    if cumulative >= unlockNumberInMeters {
                        acquisitionDate = startTime
                        break
                    }
                }

                DispatchQueue.main.async {
                    completion(acquisitionDate)
                }
            }
    }
    
    func fetchLatestCapturedAreaValue(completion: @escaping (Double?) -> Void) {
        db.collection("RunRecordModels")
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
    
// RunResultModalView를 위한 함수들
    
    // 경로 이미지 fetch
    func fetchLatestRouteImageOnly(completion: @escaping (String?) -> Void) {
        db.collection("RunRecordModels")
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
    func fetchLatestDistanceDurationCalories(completion: @escaping (_ distance: Double, _ duration: TimeInterval, _ calories: Double) -> Void) {
        db.collection("RunRecordModels")
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
    
    // running list view를 위한 함수
    func fetchAllRunSummaries(completion: @escaping ([RunSummary]) -> Void) {
        db.collection("RunRecordModels")
            .order(by: "start_time", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 전체 요약 가져오기 실패: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("❌ 문서 없음")
                    completion([])
                    return
                }

                print("🔥 서버에서 받은 문서 개수: \(documents.count)")

                let summaries: [RunSummary] = documents.compactMap { doc -> RunSummary? in
                    let data = doc.data()
                    print("데이터 확인:", data)

                    let distance = data["distance"] as? Double ?? 0
                    let startTimestamp = data["start_time"] as? Timestamp
                    let endTimestamp = data["end_time"] as? Timestamp

                    guard let start = startTimestamp?.dateValue(), let end = endTimestamp?.dateValue() else {
                        print("⛔️ 시간 필드 누락 혹은 변환 실패 - 문서ID: \(doc.documentID)")
                        return nil  // 이 문서만 제외
                    }

                    let duration = end.timeIntervalSince(start)
                    let calories = duration / 60 * 7.4

                    let area: Double = {
                        if let value = data["capturedAreaValue"] as? Double {
                            return value
                        } else if let valueInt = data["capturedAreaValue"] as? Int {
                            return Double(valueInt)
                        } else {
                            return 0
                        }
                    }()

                    let routeImageURL: URL? = {
                        if let urlString = data["routeImage"] as? String {
                            return URL(string: urlString)
                        }
                        return nil
                    }()
                    
                    let coordinatesData = data["coordinates"] as? [Any] ?? []
                    let coordinates: [CoordinatePair] = coordinatesData.compactMap {
                        if let coordDict = $0 as? [String: Any],
                           let lat = coordDict["latitude"] as? Double,
                           let lon = coordDict["longitude"] as? Double {
                            return CoordinatePair(latitude: lat, longitude: lon)
                        }
                        return nil
                    }

                    let capturedAreasData = data["captured_areas"] as? [Any] ?? []
                    let capturedAreas: [CoordinatePairWithGroup] = capturedAreasData.compactMap {
                        if let dict = $0 as? [String: Any],
                           let lat = dict["latitude"] as? Double,
                           let lon = dict["longitude"] as? Double,
                           let groupId = dict["groupId"] as? Int {
                            return CoordinatePairWithGroup(latitude: lat, longitude: lon, groupId: groupId)
                        }
                        return nil
                    }

                    return RunSummary(
                        routeImageURL: routeImageURL,
                        distance: distance,
                        duration: duration,
                        calories: calories,
                        capturedArea: area,
                        startTime: start,
                        coordinates: coordinates,
                        capturedAreas: capturedAreas
                    )
                }

                print("✅ 가공된 summaries 개수: \(summaries.count)")

                DispatchQueue.main.async {
                    completion(summaries)
                }
            }
    }
}
