//
//  UserRepository.swift
//  WAY_GYM
//
//  Created by 이주현 on 2/6/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

protocol UserRepositoryProtocol {
    func doesUserExist(uid: String) async throws -> Bool
    func isFriendCodeAvailable(_ friendCode: String) async throws -> Bool
    func saveProfile(uid: String, profile: UserProfile) async throws
    func fetchUserProfile(uid: String) async throws -> UserProfile
    func fetchUserCountByHomeArea(_ homeArea: String) async throws -> Int
    func searchUsers(matching query: String) async throws -> [UserProfile]
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
        let normalized = friendCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else { return false }
        let exists = try await firebaseManager.existsWhereEqual(
            path: "Users",
            field: "friendCode",
            isEqualTo: normalized,
            limit: 1
        )
        return !exists
    }

    func saveProfile(uid: String, profile: UserProfile) async throws {
        var data = try Firestore.Encoder().encode(profile)
        if let displayName = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           displayName.isEmpty == false {
            data["displayName"] = displayName.lowercased()
        }
        if let friendCode = profile.friendCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           friendCode.isEmpty == false {
            data["friendCode"] = friendCode.lowercased()
        }
        try await firebaseManager.set(path: "Users/\(uid)", data: data, merge: true)
    }

    func fetchUserProfile(uid: String) async throws -> UserProfile {
        try await firebaseManager.fetch(path: "Users/\(uid)")
    }

    func fetchUserCountByHomeArea(_ homeArea: String) async throws -> Int {
        let users: [UserProfile] = try await firebaseManager.fetchWhereEqual(
            path: "Users",
            field: "homeArea",
            isEqualTo: homeArea
        )
        return users.count
    }

    func searchUsers(matching query: String) async throws -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }
        let normalized = trimmed.lowercased()

        let nameMatches: [UserProfile] = try await firebaseManager.fetchWhereEqual(
            path: "Users",
            field: "displayName",
            isEqualTo: normalized
        )
        let codeMatches: [UserProfile] = try await firebaseManager.fetchWhereEqual(
            path: "Users",
            field: "friendCode",
            isEqualTo: normalized
        )

        var seen = Set<String>()
        var merged: [UserProfile] = []
        for user in nameMatches + codeMatches {
            let key = user.id ?? "\(user.displayName ?? "")|\(user.friendCode ?? "")"
            if seen.insert(key).inserted {
                merged.append(user)
            }
        }
        return merged
    }
}
