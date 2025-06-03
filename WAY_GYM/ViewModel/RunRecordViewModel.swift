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

class RunRecordViewModel: ObservableObject {
    @Published var runRecords: [RunRecordModels] = []
    
    @Published var totalDistance: Double = 0.0
    @Published var totalCapturedAreaValue: Int = 0
    
    private var db = Firestore.firestore()
    
    // 서버에서 런닝 기록 가져오기
    func fetchRunRecordsFromFirestore() {
        db.collection("RunRecordsModels")
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
                        print("✅ distance 값: \(value)")
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
                        print("✅ 총 area 값: \(value)")
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
    func fetchRunRecordsAndCalculateAcquisitionDate(for unlockNumber: Double, completion: @escaping (Date?) -> Void) {
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
}
