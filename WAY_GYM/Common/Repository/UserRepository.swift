//
//  UserRepository.swift
//  WAY_GYM
//
//  Created by 이주현 on 2/6/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

protocol UserRepositoryProtocol {
    func doesUserExist(uid: String) async throws -> Bool
    func isFriendCodeAvailable(_ friendCode: String) async throws -> Bool
    func saveProfile(uid: String, profile: User) async throws
    func updateProfile(uid: String, displayName: String, homeArea: String, sex: String) async throws
    func fetchUserProfile(uid: String) async throws -> User
    func fetchUserCountByHomeArea(_ homeArea: String) async throws -> Int
    func searchUsers(matching query: String) async throws -> [User]
}

final class UserRepository: UserRepositoryProtocol {
    private let firebaseManager: FirestoreManagerProtocol
    init(firebaseManager: FirestoreManagerProtocol = FirestoreManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func doesUserExist(uid: String) async throws -> Bool {
        let path = FirestoreDocumentPath(collection: .users, documentId: uid)
        return try await firebaseManager.documentExists(path: path)
    }

    func isFriendCodeAvailable(_ friendCode: String) async throws -> Bool {
        guard friendCode.isEmpty == false else { return false }
        let exists = try await firebaseManager.existsWhereEqual(
            path: FirestoreCollectionPath(.users),
            field: User.Field.friendCode,
            isEqualTo: friendCode,
            limit: 1
        )
        return !exists
    }

    func saveProfile(uid: String, profile: User) async throws {
        let data = try Firestore.Encoder().encode(profile)
        let path = FirestoreDocumentPath(collection: .users, documentId: uid)
        try await firebaseManager.set(path: path, data: data, merge: true)
    }

    func updateProfile(uid: String, displayName: String, homeArea: String, sex: String) async throws {
        let path = FirestoreDocumentPath(collection: .users, documentId: uid)
        let data = firestoreData(
            (User.Field.displayName, displayName),
            (User.Field.homeArea, homeArea),
            (User.Field.sex, sex)
        )
        try await firebaseManager.set(path: path, data: data, merge: true)
    }

    func fetchUserProfile(uid: String) async throws -> User {
        let path = FirestoreDocumentPath(collection: .users, documentId: uid)
        return try await firebaseManager.fetch(path: path)
    }

    func fetchUserCountByHomeArea(_ homeArea: String) async throws -> Int {
        let users: [User] = try await firebaseManager.fetchWhereEqual(
            path: FirestoreCollectionPath(.users),
            field: User.Field.homeArea,
            isEqualTo: homeArea
        )
        return users.count
    }

    func searchUsers(matching query: String) async throws -> [User] {
        guard query.isEmpty == false else { return [] }

        let nameMatches: [User] = try await firebaseManager.fetchWhereEqual(
            path: FirestoreCollectionPath(.users),
            field: User.Field.displayName,
            isEqualTo: query
        )
        let codeMatches: [User] = try await firebaseManager.fetchWhereEqual(
            path: FirestoreCollectionPath(.users),
            field: User.Field.friendCode,
            isEqualTo: query
        )

        let currentUid = Auth.auth().currentUser?.uid
        var seen = Set<String>()
        var merged: [User] = []
        for user in nameMatches + codeMatches {
            if let currentUid, user.id == currentUid {
                continue
            }
            let key = user.id ?? "\(user.displayName ?? "")|\(user.friendCode ?? "")"
            if seen.insert(key).inserted {
                merged.append(user)
            }
        }
        return merged
    }
}
