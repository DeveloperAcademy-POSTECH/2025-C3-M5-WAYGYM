//
//  UserRepository.swift
//  WAY_GYM
//
//  Created by Codex on 2/6/25.
//

import Foundation

protocol UserRepositoryProtocol {
    func doesUserExist(uid: String) async throws -> Bool
    func isFriendCodeAvailable(_ friendCode: String) async throws -> Bool
    func saveProfile(uid: String, data: [String: Any]) async throws
}

final class UserRepository: UserRepositoryProtocol {
    private let firebaseManager: FirebaseManagerProtocol

    init(firebaseManager: FirebaseManagerProtocol = FirebaseManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func doesUserExist(uid: String) async throws -> Bool {
        try await firebaseManager.documentExists(path: "Users/\(uid)")
    }

    func isFriendCodeAvailable(_ friendCode: String) async throws -> Bool {
        let exists = try await firebaseManager.existsWhereEqual(
            path: "Users",
            field: "friendCode",
            isEqualTo: friendCode,
            limit: 1
        )
        return !exists
    }

    func saveProfile(uid: String, data: [String: Any]) async throws {
        try await firebaseManager.set(path: "Users/\(uid)", data: data, merge: true)
    }
}
