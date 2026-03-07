//
//  RunRecordRepository.swift
//  WAY_GYM
//
//  Created by 이주현 on 2/6/25.
//

import Foundation
import FirebaseFirestore

protocol RunRecordRepositoryProtocol {
    func fetchUserRunRecords(uid: String) async throws -> [RunRecord]

    func fetchLatestRunRecord(uid: String) async throws -> RunRecord?
    func saveRunRecord(uid: String, record: RunRecord) async throws -> String
    func saveWorldCells(
        worldId: String,
        ownerUid: String,
        runId: String,
        cellIds: [String],
        lastCapturedAt: Date
    ) async throws
}

final class RunRecordRepository: RunRecordRepositoryProtocol {
    private let firebaseManager: FirestoreManagerProtocol

    init(firebaseManager: FirestoreManagerProtocol = FirestoreManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func fetchUserRunRecords(uid: String) async throws -> [RunRecord] {
        let snapshot = try await Firestore.firestore()
            .collection(FirestoreCollection.runRecords)
            .document(uid)
            .collection(RunRecord.Collection.runs)
            .order(by: RunRecord.Field.startTime, descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { mapRunRecord(doc: $0) }
    }

    func fetchLatestRunRecord(uid: String) async throws -> RunRecord? {
        let snapshot = try await Firestore.firestore()
            .collection(FirestoreCollection.runRecords)
            .document(uid)
            .collection(RunRecord.Collection.runs)
            .order(by: RunRecord.Field.startTime, descending: true)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.compactMap { mapRunRecord(doc: $0) }.first
    }

    func saveRunRecord(uid: String, record: RunRecord) async throws -> String {
        return try await firebaseManager.createWithAutoId(
            path: RunRecord.collectionPath(uid: uid),
            data: record
        )
    }

    func saveWorldCells(
        worldId: String,
        ownerUid: String,
        runId: String,
        cellIds: [String],
        lastCapturedAt: Date
    ) async throws {
        guard cellIds.isEmpty == false else { return }

        for cellId in cellIds {
            let cell = WorldCell(
                id: nil,
                ownerUid: ownerUid,
                lastCapturedAt: lastCapturedAt,
                lastCapturedRunId: runId
            )
            let data = try Firestore.Encoder().encode(cell)
            let path = "Worlds/\(worldId)/cells/\(cellId)"
            try await firebaseManager.set(path: path, data: data, merge: true)
        }
    }

    private func mapRunRecord(doc: QueryDocumentSnapshot) -> RunRecord? {
        let data = doc.data()

        guard let startTS = data.value(RunRecord.Field.startTime) as? Timestamp else { return nil }
        let startTime = startTS.dateValue()

        let endTime: Date? = {
            if let ts = data.value(RunRecord.Field.endTime) as? Timestamp { return ts.dateValue() }
            return nil
        }()

        let distanceM: Double = {
            if let d = data.value(RunRecord.Field.distanceM) as? Double { return d }
            if let i = data.value(RunRecord.Field.distanceM) as? Int { return Double(i) }
            return 0
        }()

        let routeEncoded = (data.value(RunRecord.Field.routeEncoded) as? String) ?? ""

        let capturedCellIds: [String] = {
            if let arr = data.value(RunRecord.Field.capturedCellIds) as? [String] { return arr }
            return []
        }()

        let routeFrame: [Double] = {
            if let arr = data.value(RunRecord.Field.routeFrame) as? [Double] { return arr }
            if let arr = data.value(RunRecord.Field.routeFrame) as? [NSNumber] { return arr.map { $0.doubleValue } }
            return [0, 0, 0, 0]
        }()

        let type: RunRecordType? = {
            if let raw = data.value(RunRecord.Field.type) as? String {
                return RunRecordType(rawValue: raw)
            }
            return nil
        }()

        let activeDuoWorldId = data.value(RunRecord.Field.activeDuoWorldId) as? String

        return RunRecord(
            id: doc.documentID,
            type: type,
            activeDuoWorldId: activeDuoWorldId,
            startTime: startTime,
            endTime: endTime,
            distanceM: distanceM,
            routeEncoded: routeEncoded,
            capturedCellIds: capturedCellIds,
            routeFrame: routeFrame
        )
    }
}
