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

class RunRecordService: ObservableObject {
    @Published var runRecords: [RunRecordModels] = []
    @Published var totalDistance: Double = 0.0
    @Published var totalCapturedAreaValue: Int = 0
    
    private var db = Firestore.firestore()
    private var isDistanceLoaded = false

    // 서버에서 총 거리 가져오기
    func fetchAndSumDistances(completion: @escaping (Double) -> Void) {
        if isDistanceLoaded {
            completion(totalDistance)
            return
        }

        db.collection("RunRecordModels")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("⚠️ 런닝 총거리 불러오기 실패: \(error?.localizedDescription ?? "")")
                    completion(0.0)
                    return
                }

                let distances = documents.compactMap { doc -> Double? in
                    doc.data()["distance"] as? Double
                }

                let sum = distances.reduce(0, +)

                DispatchQueue.main.async {
                    self?.totalDistance = sum
                    self?.isDistanceLoaded = true
                    print("🎯 총 달린 거리 계산 완료: \(sum)")
                    completion(sum)
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
    
// RunResultModalView를 위한 함수들
    // 최신 런닝 결과를 한 번에 fetch (routeImage / distance / duration / calories / capturedAreaValue)
    
    // running list view를 위한 함수
    
    func fetchAllProfileRunSummaries(completion: @escaping ([RunSummaryProfile]) -> Void) {
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

                let summaries: [RunSummaryProfile] = documents.compactMap { doc -> RunSummaryProfile? in
                    let data = doc.data()
                    // print("데이터 확인:", data)

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

                    let summary = RunSummaryProfile(
                        id: doc.documentID,
                        routeImageURL: routeImageURL,
                        distance: distance,
                        duration: duration,
                        calories: calories,
                        capturedArea: area,
                        startTime: start
                    )
                    
                    // 디버깅 출력
                    print("▶️ 요약 데이터 - id: \(summary.id)")
                    print("   distance: \(summary.distance), duration: \(summary.duration), calories: \(summary.calories)")
                    print("   capturedArea: \(summary.capturedArea), startTime: \(summary.startTime.formatted())")
                    print("   routeImageURL: \(summary.routeImageURL?.absoluteString ?? "없음")")
                    
                    return summary
                }

                print("✅ 가공된 summaries 개수: \(summaries.count)")

                DispatchQueue.main.async {
                    completion(summaries)
                }
            }
    }
    
    // running detail view
    func fetchRunSummary(by id: String, completion: @escaping (RunSummary?) -> Void) {
        db.collection("RunRecordModels").document(id).getDocument { document, error in
            if let error = error {
                print("❌ 단일 요약 가져오기 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let doc = document, doc.exists else {
                print("❌ 문서 없음 - ID: \(id)")
                completion(nil)
                return
            }

            let data = doc.data() ?? [:]
            print("📄 단일 문서 데이터 확인:", data)

            let distance = data["distance"] as? Double ?? 0
            let startTimestamp = data["start_time"] as? Timestamp
            let endTimestamp = data["end_time"] as? Timestamp

            guard let start = startTimestamp?.dateValue(), let end = endTimestamp?.dateValue() else {
                print("⛔️ 시간 필드 누락 또는 변환 실패 - 문서ID: \(doc.documentID)")
                completion(nil)
                return
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

            let summary = RunSummary(
                id: doc.documentID,
                routeImageURL: routeImageURL,
                distance: distance,
                duration: duration,
                calories: calories,
                capturedArea: area,
                startTime: start,
                coordinates: coordinates,
                capturedAreas: capturedAreas
            )

            DispatchQueue.main.async {
                completion(summary)
            }
        }
    }
}
