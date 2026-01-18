//
//  RunRecordModelsRepository.swift
//  WAY_GYM
//
//  Created by Codex on 2/6/25.
//

import Foundation

struct RunRecordLegacySummary: Decodable {
    let distance: Double
    let startTime: Date

    enum CodingKeys: String, CodingKey {
        case distance
        case startTime = "start_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(Double.self, forKey: .distance) {
            distance = value
        } else if let value = try? container.decode(Int.self, forKey: .distance) {
            distance = Double(value)
        } else {
            distance = 0
        }
        startTime = try container.decode(Date.self, forKey: .startTime)
    }
}

protocol RunRecordModelsRepositoryProtocol {
    func fetchAllRunRecordSummaries() async throws -> [RunRecordLegacySummary]
}

final class RunRecordModelsRepository: RunRecordModelsRepositoryProtocol {
    private let firebaseManager: FirebaseManagerProtocol

    init(firebaseManager: FirebaseManagerProtocol = FirebaseManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func fetchAllRunRecordSummaries() async throws -> [RunRecordLegacySummary] {
        try await firebaseManager.fetchCollection(path: "RunRecordModels")
    }
}
