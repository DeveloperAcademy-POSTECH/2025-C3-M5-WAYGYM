//
//  RewardRepository.swift
//  WAY_GYM
//
//  Created by 이주현 on 3/7/26.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

protocol RewardRepositoryProtocol {
    func hasUnlockedMinions(uid: String) async throws -> Bool
    func fetchMinionUnlocks(uid: String) async throws -> [MinionUnlock]
}

final class RewardRepository: RewardRepositoryProtocol {
    private let firebaseManager: FirestoreManagerProtocol

    init(firebaseManager: FirestoreManagerProtocol = FirestoreManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func hasUnlockedMinions(uid: String) async throws -> Bool {
        let path = FirestoreCollectionPath(rawValue: "Users/\(uid)/minionUnlocks")
        let unlocks: [MinionUnlock] = try await firebaseManager.fetchCollection(
            path: path,
            orderBy: "unlockedAt",
            descending: true,
            limit: 1
        )
        return !unlocks.isEmpty
    }

    func fetchMinionUnlocks(uid: String) async throws -> [MinionUnlock] {
        let path = FirestoreCollectionPath(rawValue: "Users/\(uid)/minionUnlocks")
        return try await firebaseManager.fetchCollection(
            path: path,
            orderBy: "unlockedAt",
            descending: true
        )
    }
}
