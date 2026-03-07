import Foundation

@MainActor
final class FriendViewModel: ObservableObject {
    private let userRepository: UserRepositoryProtocol
    private let friendRepository: FriendRepositoryProtocol

    init(
        userRepository: UserRepositoryProtocol = UserRepository(),
        friendRepository: FriendRepositoryProtocol = FriendRepository()
    ) {
        self.userRepository = userRepository
        self.friendRepository = friendRepository
    }

    // MARK: - FriendView
    func searchUsers(matching query: String) async throws -> [User] {
        try await userRepository.searchUsers(matching: query)
    }

    func fetchFriendProfiles(uids: [String]) async -> [User] {
        guard !uids.isEmpty else { return [] }

        var fetched: [User] = []
        await withTaskGroup(of: User?.self) { group in
            for uid in uids {
                group.addTask { [userRepository] in
                    try? await userRepository.fetchUserProfile(uid: uid)
                }
            }

            for await profile in group {
                if let profile {
                    fetched.append(profile)
                }
            }
        }

        return fetched
    }

    // MARK: - 친구 신청
    func sendFriendRequest(fromUid: String, toUid: String) async throws {
        try await friendRepository.sendFriendRequest(fromUid: fromUid, toUid: toUid)
    }

    func acceptRequest(fromUid: String, toUid: String) async throws {
        let ordered = [fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let requestId = "\(ordered[0])_\(ordered[1])"

        try await friendRepository.acceptFriendRequest(
            requestId: requestId,
            fromUid: fromUid,
            toUid: toUid
        )
    }

    // MARK: - 점령전
    func sendWorldRequest(fromUid: String, toUid: String) async throws {
        try await friendRepository.sendWorldRequest(fromUid: fromUid, toUid: toUid)
    }

    func acceptWorldRequest(fromUid: String, toUid: String) async throws {
        try await friendRepository.acceptWorldRequest(fromUid: fromUid, toUid: toUid)
    }
    
}
