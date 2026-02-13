import Foundation

@MainActor
final class FriendViewModel: ObservableObject {
    private let friendRepository: FriendRepositoryProtocol

    init(friendRepository: FriendRepositoryProtocol = FriendRepository()) {
        self.friendRepository = friendRepository
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
}
