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
    ///
    @Published private(set) var outgoingWorldRequestUids: Set<String> = [] /// 내가 경쟁전 신청한 친구들
    @Published private(set) var incomingWorldRequestUids: Set<String> = [] /// 내게 경쟁전 신청한 친구들
    @Published private(set) var activeDuoOpponentUid: String? /// 나와 경쟁전 플레이 중인 친구 uid
    @Published private(set) var lastRefreshError: String?

    private let friendRepository: FriendRepositoryProtocol
    private let userRepository: UserRepositoryProtocol

    init(
        friendRepository: FriendRepositoryProtocol = FriendRepository(),
        userRepository: UserRepositoryProtocol = UserRepository()
    ) {
        self.friendRepository = friendRepository
        self.userRepository = userRepository
    }

    @MainActor
    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            resetFriendStore()
            return
        }

        lastRefreshError = nil
        do {
            activeDuoOpponentUid = nil

            // 내 activeDuoWorldId가 있다면 Worlds/{id}에서 상대 uid를 해석한다.
            let myProfile = try await userRepository.fetchUserProfile(uid: uid)
            let activeWorldId = myProfile.activeDuoWorldId

            let friendships = try await friendRepository.fetchFriendships(for: uid)
            let friends = friendships.compactMap { $0.otherUid(for: uid) }
            friendUids = Set(friends)

            let outgoing = try await friendRepository.fetchPendingFriendRequestsSent(from: uid)
            outgoingPendingUids = Set(outgoing.map { $0.toUid })

            let incoming = try await friendRepository.fetchPendingFriendRequestsReceived(to: uid)
            incomingPendingUids = Set(incoming.map { $0.fromUid })

            let outgoingWorld = try await friendRepository.fetchPendingWorldRequestsSent(from: uid)
            let incomingWorld = try await friendRepository.fetchPendingWorldRequestsReceived(to: uid)
            let friendSet = Set(friends)
            outgoingWorldRequestUids = Set(outgoingWorld.map { $0.toUid }).intersection(friendSet)
            incomingWorldRequestUids = Set(incomingWorld.map { $0.fromUid }).intersection(friendSet)

            if let activeWorldId {
                let memberUids = try await friendRepository.fetchWorldMemberUids(worldId: activeWorldId)
                let opponentUid = memberUids.first { $0 != uid }
                if let opponentUid, friendSet.contains(opponentUid) {
                    activeDuoOpponentUid = opponentUid
                }
            }
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
        outgoingWorldRequestUids = []
        incomingWorldRequestUids = []
        activeDuoOpponentUid = nil
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

    @MainActor
    func markOutgoingWorldRequest(uid: String) {
        outgoingWorldRequestUids.insert(uid)
        incomingWorldRequestUids.remove(uid)
    }

    @MainActor
    func unmarkOutgoingWorldRequest(uid: String) {
        outgoingWorldRequestUids.remove(uid)
    }

    @MainActor
    func markAcceptedWorldRequest(uid: String) {
        incomingWorldRequestUids.remove(uid)
        outgoingWorldRequestUids.remove(uid)
    }

    @MainActor
    func restoreIncomingWorldRequest(uid: String) {
        incomingWorldRequestUids.insert(uid)
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
