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
    func fetchFriendships(for uid: String) async throws -> [Friendship]
    
    func sendFriendRequest(fromUid: String, toUid: String) async throws
    func fetchPendingFriendRequestsSent(from uid: String) async throws -> [FriendRequest]
    func fetchPendingFriendRequestsReceived(to uid: String) async throws -> [FriendRequest]
    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws
    
    func sendWorldRequest(fromUid: String, toUid: String) async throws
    func fetchPendingWorldRequestsSent(from uid: String) async throws -> [WorldRequest]
    func fetchPendingWorldRequestsReceived(to uid: String) async throws -> [WorldRequest]
    func acceptWorldRequest(fromUid: String, toUid: String) async throws

    /// Worlds/{worldId}의 memberUids를 가져온다.
    func fetchWorldMemberUids(worldId: String) async throws -> [String]
}

final class FriendRepository: FriendRepositoryProtocol {
    private let firebaseManager: FirestoreManagerProtocol
    init(firebaseManager: FirestoreManagerProtocol = FirestoreManager.shared) {
        self.firebaseManager = firebaseManager
    }

    private struct DuoWorld: Decodable {
        let memberUids: [String]
    }

    func fetchFriendships(for uid: String) async throws -> [Friendship] {
        let matches: [Friendship] = try await firebaseManager.fetchWhereArrayContains(
            path: FirestoreCollectionPath(.friendships),
            field: Friendship.Field.memberUids,
            value: uid
        )
        return matches
    }

    func sendFriendRequest(fromUid: String, toUid: String) async throws {
        let ordered = [fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let uidA = ordered[0]
        let uidB = ordered[1]
        let requestId = "\(uidA)_\(uidB)"

        try await firebaseManager.runTransaction { transaction, errorPointer in
            let db = Firestore.firestore()
            let requestRef = db.collection(FirestoreCollection.friendRequests).document(requestId)
            let friendshipRef = db.collection(FirestoreCollection.friendships).document(requestId)

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
        }
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

        try await firebaseManager.runTransaction { transaction, errorPointer in
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
        }
    }

    func sendWorldRequest(fromUid: String, toUid: String) async throws {
        async let myUser: User = firebaseManager.fetch(
            path: FirestoreDocumentPath(collection: .users, documentId: fromUid)
        )
        async let otherUser: User = firebaseManager.fetch(
            path: FirestoreDocumentPath(collection: .users, documentId: toUid)
        )

        let (me, other) = try await (myUser, otherUser)
        guard me.activeDuoWorldId == nil, other.activeDuoWorldId == nil else {
            return
        }

        let ordered = [fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let uidA = ordered[0]
        let uidB = ordered[1]
        let requestId = "\(uidA)_\(uidB)"

        let data = firestoreData(
            (WorldRequest.Field.fromUid, fromUid),
            (WorldRequest.Field.toUid, toUid),
            (WorldRequest.Field.status, "pending"),
            (WorldRequest.Field.createdAt, FieldValue.serverTimestamp())
        )

        try await firebaseManager.create(
            path: FirestoreDocumentPath(collection: .worldRequests, documentId: requestId),
            data: data
        )
    }

    func fetchPendingWorldRequestsSent(from uid: String) async throws -> [WorldRequest] {
        let requests: [WorldRequest] = try await firebaseManager.fetchWhereEqual(
            path: FirestoreCollectionPath(.worldRequests),
            field: WorldRequest.Field.fromUid,
            isEqualTo: uid
        )
        return requests.filter { $0.status == "pending" }
    }

    func fetchPendingWorldRequestsReceived(to uid: String) async throws -> [WorldRequest] {
        let requests: [WorldRequest] = try await firebaseManager.fetchWhereEqual(
            path: FirestoreCollectionPath(.worldRequests),
            field: WorldRequest.Field.toUid,
            isEqualTo: uid
        )
        return requests.filter { $0.status == "pending" }
    }

    func acceptWorldRequest(fromUid: String, toUid: String) async throws {
        let ordered = [fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let uidA = ordered[0]
        let uidB = ordered[1]
        let requestId = "\(uidA)_\(uidB)"
        let worldId = UUID().uuidString
        let createdAt = Date()
        let endsAt = Date().addingTimeInterval(15 * 24 * 60 * 60)

        let db = Firestore.firestore()
        let requestRef = db.collection(FirestoreCollection.worldRequests).document(requestId)
        let userRefA = db.collection(FirestoreCollection.users).document(uidA)
        let userRefB = db.collection(FirestoreCollection.users).document(uidB)
        let worldRef = db.collection("Worlds").document(worldId)

        // uidA 또는 uidB가 얽혀 있는 모든 다른 pending 점령전 요청들
        let pendingBase = db.collection(FirestoreCollection.worldRequests)
            .whereField(WorldRequest.Field.status, isEqualTo: "pending")
        let pendingOutgoing = try await pendingBase
            .whereField(WorldRequest.Field.fromUid, in: [uidA, uidB])
            .getDocuments()
        let pendingIncoming = try await pendingBase
            .whereField(WorldRequest.Field.toUid, in: [uidA, uidB])
            .getDocuments()
        let otherPendingRefs: [DocumentReference] =
            (pendingOutgoing.documents + pendingIncoming.documents)
                .filter { $0.documentID != requestId }
                .map { $0.reference }

        try await firebaseManager.runTransaction { transaction, errorPointer in
            func fail(_ message: String) -> Any? {
                errorPointer?.pointee = NSError(
                    domain: "FriendRepository.acceptWorldRequest",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
                return nil
            }

            let requestSnapshot: DocumentSnapshot
            let userSnapshotA: DocumentSnapshot
            let userSnapshotB: DocumentSnapshot

            do {
                requestSnapshot = try transaction.getDocument(requestRef)
                userSnapshotA = try transaction.getDocument(userRefA)
                userSnapshotB = try transaction.getDocument(userRefB)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            // world_requests/{uidA_uidB}가 pending인지 확인
            guard requestSnapshot.exists else {
                return fail("world_request 문서가 없습니다: \(requestId)")
            }
            let status = requestSnapshot.data()?.value(WorldRequest.Field.status) as? String
            guard status == "pending" else {
                return fail("world_request 상태가 pending이 아닙니다: \(status ?? "nil")")
            }

            // Users/{uidA}, Users/{uidB}의 activeDuoWorldId == nil 확인
            let activeA = userSnapshotA.data()?["activeDuoWorldId"] as? String
            let activeB = userSnapshotB.data()?["activeDuoWorldId"] as? String
            guard activeA == nil, activeB == nil else {
                return fail("이미 activeDuoWorldId가 있습니다. activeA=\(activeA ?? "nil"), activeB=\(activeB ?? "nil")")
            }

            // 요청 상태를 accepted로 변경
            transaction.updateData(
                firestoreData((WorldRequest.Field.status, "accepted")),
                forDocument: requestRef
            )
            
            // Worlds/{worldId} 생성
            let world = World(
                id: worldId,
                memberUids: [uidA, uidB],
                createdAt: createdAt,
                endsAt: endsAt,
                status: "active",
                winnerUid: nil
            )
            let worldData: [String: Any]
            do {
                worldData = try Firestore.Encoder().encode(world)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            transaction.setData(worldData, forDocument: worldRef, merge: true)

            // 두 유저의 activeDuoWorldId 세팅
            transaction.updateData(
                firestoreData((User.Field.activeDuoWorldId, worldId)),
                forDocument: userRefA
            )
            transaction.updateData(
                firestoreData((User.Field.activeDuoWorldId, worldId)),
                forDocument: userRefB
            )

            // uidA/uidB가 관련된 다른 pending 요청은 전부 canceled 처리
            for ref in otherPendingRefs {
                transaction.updateData(
                    firestoreData((WorldRequest.Field.status, "canceled")),
                    forDocument: ref
                )
            }

            return nil
        }
    }

    func fetchWorldMemberUids(worldId: String) async throws -> [String] {
        let path = "Worlds/\(worldId)"
        let world: DuoWorld = try await firebaseManager.fetch(path: path)
        return world.memberUids
    }
}
