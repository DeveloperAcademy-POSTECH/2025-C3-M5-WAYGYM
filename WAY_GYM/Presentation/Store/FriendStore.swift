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
    @Published private(set) var friendUids: Set<String> = [] /// 나와 친구 관계인 사람들
    @Published private(set) var outgoingPendingUids: Set<String> = [] /// 내가 친구신청을 보낸 사람들
    @Published private(set) var incomingPendingUids: Set<String> = [] /// 내게 친구신청을 보낸 사람들
    @Published private(set) var lastRefreshError: String?

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

        lastRefreshError = nil
        do {
            let friendships = try await friendRepository.fetchFriendships(for: uid)
            let friends = friendships.compactMap { $0.otherUid(for: uid) }
            friendUids = Set(friends)

            let outgoing = try await friendRepository.fetchPendingFriendRequestsSent(from: uid)
            outgoingPendingUids = Set(outgoing.map { $0.toUid })

            let incoming = try await friendRepository.fetchPendingFriendRequestsReceived(to: uid)
            incomingPendingUids = Set(incoming.map { $0.fromUid })
        } catch {
            lastRefreshError = error.localizedDescription
            print("⚠️ FriendStore refresh 실패: \(error.localizedDescription)")
        }
    }

    @MainActor
    func resetFriendStore() {
        friendUids = []
        outgoingPendingUids = []
        incomingPendingUids = []
        lastRefreshError = nil
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

#if DEBUG
    @MainActor
    static func previewWithError(_ message: String) -> FriendStore {
        let store = FriendStore()
        store.lastRefreshError = message
        return store
    }
#endif
}
