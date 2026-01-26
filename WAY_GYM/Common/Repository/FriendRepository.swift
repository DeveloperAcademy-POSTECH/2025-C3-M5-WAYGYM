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
    private let firebaseManager: FirestoreManagerProtocol
    init(firebaseManager: FirestoreManagerProtocol = FirestoreManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func sendFriendRequest(fromUid: String, toUid: String) async throws {
        let ordered = [fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let uidA = ordered[0]
        let uidB = ordered[1]
        let requestId = "\(uidA)_\(uidB)"

        let db = Firestore.firestore()
        let requestRef = db.collection(FirestoreCollection.friendRequests).document(requestId)
        let friendshipRef = db.collection(FirestoreCollection.friendships).document(requestId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer in
                let requestSnapshot: DocumentSnapshot
                let friendshipSnapshot: DocumentSnapshot

                do {
                    requestSnapshot = try transaction.getDocument(requestRef)
                    friendshipSnapshot = try transaction.getDocument(friendshipRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                if friendshipSnapshot.exists {
                    return nil
                }

        if requestSnapshot.exists {
                    if let status = requestSnapshot.data()?.value(FriendRequest.Field.status) as? String,
                       status == "pending" || status == "accepted" {
                        return nil
                    }
                }

                let data = firestoreData(
                    (FriendRequest.Field.fromUid, fromUid),
                    (FriendRequest.Field.toUid, toUid),
                    (FriendRequest.Field.status, "pending")
                )
                transaction.setData(data, forDocument: requestRef, merge: true)
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

    func fetchFriendships(for uid: String) async throws -> [Friendship] {
        let matches: [Friendship] = try await firebaseManager.fetchWhereArrayContains(
            path: FirestoreCollectionPath(.friendships),
            field: Friendship.Field.memberUids,
            value: uid
        )
        return matches
    }

    func fetchPendingFriendRequestsSent(from uid: String) async throws -> [FriendRequest] {
        let requests: [FriendRequest] = try await firebaseManager.fetchWhereEqual(
            path: FirestoreCollectionPath(.friendRequests),
            field: FriendRequest.Field.fromUid,
            isEqualTo: uid
        )
        return requests.filter { $0.status == "pending" }
    }

    func fetchPendingFriendRequestsReceived(to uid: String) async throws -> [FriendRequest] {
        let requests: [FriendRequest] = try await firebaseManager.fetchWhereEqual(
            path: FirestoreCollectionPath(.friendRequests),
            field: FriendRequest.Field.toUid,
            isEqualTo: uid
        )
        return requests.filter { $0.status == "pending" }
    }

    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws {
        let ordered = [fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let uidA = ordered[0]
        let uidB = ordered[1]
        let pairId = "\(uidA)_\(uidB)"

        let db = Firestore.firestore()
        let requestRef = db.collection(FirestoreCollection.friendRequests).document(pairId)
        let friendshipRef = db.collection(FirestoreCollection.friendships).document(pairId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer in
                let requestSnapshot: DocumentSnapshot
                do {
                    requestSnapshot = try transaction.getDocument(requestRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                guard requestSnapshot.exists else {
                    return nil
                }
                transaction.updateData(
                    firestoreData((FriendRequest.Field.status, "accepted")),
                    forDocument: requestRef
                )
                transaction.setData(
                    firestoreData((Friendship.Field.memberUids, [uidA, uidB])),
                    forDocument: friendshipRef,
                    merge: true
                )
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
