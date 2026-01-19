//
//  FriendStore.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import Foundation
import FirebaseAuth

enum FriendStatus {
    case alreadyFriend
    case outgoingPending
    case incomingPending
    case canRequest
}

final class FriendStore: ObservableObject {
    @Published private(set) var friendUids: Set<String> = []
    @Published private(set) var outgoingPendingUids: Set<String> = []
    @Published private(set) var incomingPendingUids: Set<String> = []

    private let friendRepository: FriendRepositoryProtocol

    init(friendRepository: FriendRepositoryProtocol = FriendRepository()) {
        self.friendRepository = friendRepository
    }

    @MainActor
    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            resetFriendStore()
            return
        }

        do {
            let friendships = try await friendRepository.fetchFriendships(for: uid)
            let friends = friendships.compactMap { $0.otherUid(for: uid) }
            friendUids = Set(friends)

            let outgoing = try await friendRepository.fetchPendingFriendRequestsSent(from: uid)
            outgoingPendingUids = Set(outgoing.map { $0.toUid })

            let incoming = try await friendRepository.fetchPendingFriendRequestsReceived(to: uid)
            incomingPendingUids = Set(incoming.map { $0.fromUid })
        } catch {
            print("⚠️ FriendStore refresh 실패: \(error.localizedDescription)")
        }
    }

    @MainActor
    func resetFriendStore() {
        friendUids = []
        outgoingPendingUids = []
        incomingPendingUids = []
    }

    func status(for uid: String) -> FriendStatus {
        if friendUids.contains(uid) {
            return .alreadyFriend
        }
        if outgoingPendingUids.contains(uid) {
            return .outgoingPending
        }
        if incomingPendingUids.contains(uid) {
            return .incomingPending
        }
        return .canRequest
    }

    @MainActor
    func markOutgoingPending(uid: String) {
        outgoingPendingUids.insert(uid)
    }
}
