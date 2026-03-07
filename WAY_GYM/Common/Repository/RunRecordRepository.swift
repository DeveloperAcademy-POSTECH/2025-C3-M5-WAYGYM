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
        try await firebaseManager.fetchCollection(
            path: RunRecord.collectionPath(uid: uid),
            orderBy: RunRecord.Field.startTime.key,
            descending: true
        )
    }

    func fetchLatestRunRecord(uid: String) async throws -> RunRecord? {
        let records: [RunRecord] = try await firebaseManager.fetchCollection(
            path: RunRecord.collectionPath(uid: uid),
            orderBy: RunRecord.Field.startTime.key,
            descending: true,
            limit: 1
        )
        return records.first
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

}
