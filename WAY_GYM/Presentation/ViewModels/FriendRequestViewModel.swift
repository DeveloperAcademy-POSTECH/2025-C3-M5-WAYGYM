import Foundation

final class FriendRequestViewModel: ObservableObject {
    @Published var requests: [FriendRequestRowModel]
    @Published var isLoading: Bool = false;

    private let userRepository: UserRepositoryProtocol
    private let friendRepository: FriendRepositoryProtocol

    init(
        requests: [FriendRequestRowModel] = [],
        userRepository: UserRepositoryProtocol = UserRepository(),
        friendRepository: FriendRepositoryProtocol = FriendRepository()
    ) {
        self.requests = requests
        self.userRepository = userRepository
        self.friendRepository = friendRepository
    }

    func loadRequests(currentUid: String?) async {
        guard let uid = currentUid else {
            requests = []
            return
        }

        isLoading = true
        do {
            requests = try await fetchPendingRequestsWithProfiles(to: uid)
            isLoading = false
        } catch {
            requests = []
            isLoading = false
        }
    }

    func acceptRequest(
        _ request: FriendRequestRowModel,
        currentUid: String?,
        friendStore: FriendStore
    ) async throws {
        guard let toUid = currentUid else { return }

        let ordered = [request.fromUid, toUid].sorted()
        guard ordered.count == 2 else { return }
        let requestId = "\(ordered[0])_\(ordered[1])"

        try await friendRepository.acceptFriendRequest(
            requestId: requestId,
            fromUid: request.fromUid,
            toUid: toUid
        )

        requests.removeAll { $0.id == request.id }
        await friendStore.refresh()
    }

    private func fetchPendingRequestsWithProfiles(to uid: String) async throws -> [FriendRequestRowModel] {
        let pending = try await fetchPendingRequests(to: uid)
        var fetched: [FriendRequestRowModel] = []

        await withTaskGroup(of: FriendRequestRowModel?.self) { group in
            for request in pending {
                guard let requestId = request.id else { continue }
                group.addTask {
                    guard let profile = try? await self.fetchProfile(uid: request.fromUid) else {
                        return nil
                    }
                    return await self.makeRow(requestId: requestId, fromUid: request.fromUid, profile: profile)
                }
            }

            for await row in group {
                if let row {
                    fetched.append(row)
                }
            }
        }

        fetched.sort { $0.displayName < $1.displayName }
        return fetched
    }

    private func fetchProfile(uid: String) async throws -> User {
        try await userRepository.fetchUserProfile(uid: uid)
    }

    private func fetchPendingRequests(to uid: String) async throws -> [FriendRequest] {
        try await friendRepository.fetchPendingFriendRequestsReceived(to: uid)
    }

    private func makeRow(requestId: String, fromUid: String, profile: User) -> FriendRequestRowModel {
        let displayName = profile.displayName ?? "알 수 없음"
        let subText: String
        if let friendCode = profile.friendCode, friendCode.isEmpty == false {
            subText = "\(friendCode)"
        } else if let homeArea = profile.homeArea, homeArea.isEmpty == false {
            subText = homeArea
        } else {
            subText = "친구 신청"
        }
        return .init(id: requestId, requestId: requestId, fromUid: fromUid, displayName: displayName, subText: subText)
    }
}

struct FriendRequestRowModel: Identifiable {
    let id: String
    let requestId: String
    let fromUid: String
    let displayName: String
    let subText: String
}
