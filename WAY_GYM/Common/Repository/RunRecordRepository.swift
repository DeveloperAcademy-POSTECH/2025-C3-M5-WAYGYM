//
//  RunRecordRepository.swift
//  WAY_GYM
//
//  Created by 이주현 on 2/6/25.
//

import Foundation
import FirebaseFirestore

protocol RunRecordRepositoryProtocol {
    func fetchUserRunRecords(uid: String) async throws -> [RunRecordModel]

    func fetchLatestRunRecord(uid: String) async throws -> RunRecordModel?
    func saveRunRecord(uid: String, record: RunRecordModel) async throws -> String
}

final class RunRecordRepository: RunRecordRepositoryProtocol {
    private let firebaseManager: FirebaseManagerProtocol

    init(firebaseManager: FirebaseManagerProtocol = FirebaseManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func fetchUserRunRecords(uid: String) async throws -> [RunRecordModel] {
        let snapshot = try await Firestore.firestore()
            .collection("RunRecords")
            .document(uid)
            .collection("runs")
            .order(by: "start_time", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { mapRunRecord(doc: $0) }
    }

    func fetchLatestRunRecord(uid: String) async throws -> RunRecordModel? {
        let snapshot = try await Firestore.firestore()
            .collection("RunRecords")
            .document(uid)
            .collection("runs")
            .order(by: "start_time", descending: true)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.compactMap { mapRunRecord(doc: $0) }.first
    }

    func saveRunRecord(uid: String, record: RunRecordModel) async throws -> String {
        let path = "RunRecords/\(uid)/runs"
        return try await firebaseManager.createWithAutoId(path: path, data: record)
    }

    private func mapRunRecord(doc: QueryDocumentSnapshot) -> RunRecordModel? {
        let data = doc.data()

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
}
