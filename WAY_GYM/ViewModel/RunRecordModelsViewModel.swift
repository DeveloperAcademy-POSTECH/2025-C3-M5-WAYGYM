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
                    print("Error fetching run records: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents in RunRecordsModels")
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
                    print("No documents or error: \(error?.localizedDescription ?? "")")
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
                    print("🎯 Total distance (fallback): \(self?.totalDistance ?? 0)")
                }
            }
    }
    
    // 서버에서 총 딴 면적 가져오기
    func fetchAndSumCapturedValue() {
        db.collection("RunRecordModels")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("No documents or error: \(error?.localizedDescription ?? "")")
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
                    print("🎯 Total capturedAreaValue 합계: \(self?.totalCapturedAreaValue ?? 0)")
                }
            }
    }
}
