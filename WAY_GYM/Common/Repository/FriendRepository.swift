//
//  FriendRepository.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

protocol FriendRepositoryProtocol {
    func sendFriendRequest(fromUid: String, toUid: String) async throws
    func fetchFriendships(for uid: String) async throws -> [Friendship]
    func fetchPendingFriendRequestsSent(from uid: String) async throws -> [FriendRequest]
    func fetchPendingFriendRequestsReceived(to uid: String) async throws -> [FriendRequest]
    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws
}

final class FriendRepository: FriendRepositoryProtocol {
    private let firebaseManager: FirebaseManagerProtocol
    init(firebaseManager: FirebaseManagerProtocol = FirebaseManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func sendFriendRequest(fromUid: String, toUid: String) async throws {
        let data: [String: Any] = [
            "fromUid": fromUid,
            "toUid": toUid,
            "status": "pending"
        ]
        _ = try await firebaseManager.createWithAutoId(path: "friend_requests", data: data)
    }

    func fetchFriendships(for uid: String) async throws -> [Friendship] {
        let matches: [Friendship] = try await firebaseManager.fetchWhereArrayContains(
            path: "friendships",
            field: "memberUids",
            value: uid
        )
        return matches
    }

    func fetchPendingFriendRequestsSent(from uid: String) async throws -> [FriendRequest] {
        let requests: [FriendRequest] = try await firebaseManager.fetchWhereEqual(
            path: "friend_requests",
            field: "fromUid",
            isEqualTo: uid
        )
        return requests.filter { $0.status == "pending" }
    }

    func fetchPendingFriendRequestsReceived(to uid: String) async throws -> [FriendRequest] {
        let requests: [FriendRequest] = try await firebaseManager.fetchWhereEqual(
            path: "friend_requests",
            field: "toUid",
            isEqualTo: uid
        )
        return requests.filter { $0.status == "pending" }
    }

    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws {
        let ordered = [fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let uidA = ordered[0]
        let uidB = ordered[1]
        let friendshipId = "\(uidA)_\(uidB)"

        let db = Firestore.firestore()
        let requestRef = db.collection("friend_requests").document(requestId)
        let friendshipRef = db.collection("friendships").document(friendshipId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, _ in
                transaction.updateData(["status": "accepted"], forDocument: requestRef)
                transaction.setData(["memberUids": [uidA, uidB]], forDocument: friendshipRef, merge: false)
                return nil
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
