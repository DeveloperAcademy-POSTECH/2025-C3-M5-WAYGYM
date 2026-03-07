import Foundation

@MainActor
final class FriendViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var isSearching: Bool = false
    @Published var isSearchLoading: Bool = false
    @Published var searchResults: [FriendUserRowModel] = []
    @Published var friends: [FriendUserRowModel] = []

    private let userRepository: UserRepositoryProtocol
    private let friendRepository: FriendRepositoryProtocol
    init(
        userRepository: UserRepositoryProtocol = UserRepository(),
        friendRepository: FriendRepositoryProtocol = FriendRepository()
    ) {
        self.userRepository = userRepository
        self.friendRepository = friendRepository
    }
    
    func tapSearch(statusResolver: (String) -> FriendStatus?) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }

        isSearching = true
        searchResults = []
        isSearchLoading = true

        do {
            let users = try await userRepository.searchUsers(matching: trimmed)
            searchResults = makeRows(from: users, statusResolver: statusResolver)
            isSearchLoading = false
        } catch {
            searchResults = []
            isSearchLoading = false
        }
    }

    func sendFriendRequest(currentUid: String?, toUid: String?, friendStore: FriendStore) async {
        do {
            guard let pair = resolveUidPair(currentUid: currentUid, otherUid: toUid) else { return }
            try await friendRepository.sendFriendRequest(fromUid: pair.current, toUid: pair.other)

            friendStore.markOutgoingPending(uid: pair.other)
            searchResults = updateSearchResultStatus(
                in: searchResults,
                uid: pair.other,
                status: .outgoingPending
            )
        } catch {
            // TODO: 에러 팝업창
        }
    }

    func acceptIncomingFriendRequest(currentUid: String?, fromUid: String?, friendStore: FriendStore) async {
        do {
            guard let pair = resolveUidPair(currentUid: currentUid, otherUid: fromUid) else { return }
            let requestId = [pair.current, pair.other].sorted().joined(separator: "_")

            try await friendRepository.acceptFriendRequest(
                requestId: requestId,
                fromUid: pair.other,
                toUid: pair.current
            )

            await friendStore.refresh()
            searchResults = updateSearchResultStatus(
                in: searchResults,
                uid: pair.other,
                status: .alreadyFriend
            )
        } catch {
            print("⚠️ acceptFriendRequest 실패: \(error.localizedDescription)")
        }
    }

    func sendWorldRequest(
        currentUid: String?,
        toUid: String?,
        friendStore: FriendStore,
        userStore: UserStore
    ) async {
        guard let targetUid = toUid else { return }

        friendStore.markOutgoingWorldRequest(uid: targetUid)
        do {
            guard let pair = resolveUidPair(currentUid: currentUid, otherUid: toUid) else {
                friendStore.unmarkOutgoingWorldRequest(uid: targetUid)
                return
            }

            try await friendRepository.sendWorldRequest(fromUid: pair.current, toUid: pair.other)
            await friendStore.refresh()
            await userStore.refresh()
        } catch {
            friendStore.unmarkOutgoingWorldRequest(uid: targetUid)
            // TODO: 에러 팝업창
        }
    }

    func acceptWorldRequest(
        currentUid: String?,
        fromUid: String?,
        friendStore: FriendStore,
        userStore: UserStore
    ) async {
        guard let fromUid else { return }

        friendStore.markAcceptedWorldRequest(uid: fromUid)
        do {
            guard let pair = resolveUidPair(currentUid: currentUid, otherUid: fromUid) else {
                friendStore.restoreIncomingWorldRequest(uid: fromUid)
                return
            }

            try await friendRepository.acceptWorldRequest(fromUid: pair.other, toUid: pair.current)
            await friendStore.refresh()
            await userStore.refresh()
        } catch {
            friendStore.restoreIncomingWorldRequest(uid: fromUid)
            print("⚠️ acceptWorldRequest 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - UI
    func fetchFriendProfiles(friendStore: FriendStore) async {
        let uids = Array(friendStore.friendUids)
        guard uids.isEmpty == false else {
            friends = []
            return
        }

        var profiles: [User] = []
        await withTaskGroup(of: User?.self) { group in
            for uid in uids {
                group.addTask { [userRepository] in
                    try? await userRepository.fetchUserProfile(uid: uid)
                }
            }

            for await profile in group {
                if let profile {
                    profiles.append(profile)
                }
            }
        }
        let rows = makeRows(from: profiles) { uid in
            friendStore.status(for: uid)
        }

        friends = sortRows(rows, with: friendStore)
    }

    func sortFriends(friendStore: FriendStore) {
        friends = sortRows(friends, with: friendStore)
    }
    
    private func makeRows(
        from users: [User],
        statusResolver: (String) -> FriendStatus?
    ) -> [FriendUserRowModel] {
        users.map { user in
            let id = user.id ?? user.friendCode ?? user.displayName ?? UUID().uuidString
            let displayName = user.displayName ?? "알 수 없음"

            let subText: String
            if let friendCode = user.friendCode, friendCode.isEmpty == false {
                subText = "\(friendCode)"
            } else if let homeArea = user.homeArea, homeArea.isEmpty == false {
                subText = homeArea
            } else {
                subText = "검색된 유저"
            }

            let status = user.id.flatMap(statusResolver)
            return .init(
                id: id,
                uid: user.id,
                displayName: displayName,
                subText: subText,
                status: status,
                activeDuoWorldId: user.activeDuoWorldId
            )
        }
    }

    private func updateSearchResultStatus(
        in rows: [FriendUserRowModel],
        uid: String,
        status: FriendStatus
    ) -> [FriendUserRowModel] {
        rows.map { row in
            guard row.uid == uid else { return row }
            return row.withStatus(status)
        }
    }

    private func sortRows(
        _ rows: [FriendUserRowModel],
        incomingWorldRequestUids: Set<String>,
        outgoingWorldRequestUids: Set<String>,
        activeDuoOpponentUid: String?
    ) -> [FriendUserRowModel] {
        var sorted = rows
        guard sorted.isEmpty == false else { return sorted }

        func priority(for uid: String?) -> Int {
            guard let uid else { return 3 }
            if activeDuoOpponentUid == uid { return 0 }
            if incomingWorldRequestUids.contains(uid) { return 1 }
            if outgoingWorldRequestUids.contains(uid) { return 2 }
            return 3
        }

        sorted.sort { lhs, rhs in
            let lp = priority(for: lhs.uid)
            let rp = priority(for: rhs.uid)
            if lp != rp { return lp < rp }

            let nameOrder = lhs.displayName.localizedStandardCompare(rhs.displayName)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return (lhs.uid ?? lhs.id) < (rhs.uid ?? rhs.id)
        }

        return sorted
    }
    
    private func sortRows(_ rows: [FriendUserRowModel], with friendStore: FriendStore) -> [FriendUserRowModel] {
        sortRows(
            rows,
            incomingWorldRequestUids: friendStore.incomingWorldRequestUids,
            outgoingWorldRequestUids: friendStore.outgoingWorldRequestUids,
            activeDuoOpponentUid: friendStore.activeDuoOpponentUid
        )
    }

    private func resolveUidPair(currentUid: String?, otherUid: String?) -> (current: String, other: String)? {
        guard let currentUid else { return nil }
        guard let otherUid, otherUid.isEmpty == false else { return nil }
        guard currentUid != otherUid else { return nil }
        return (current: currentUid, other: otherUid)
    }
}

struct FriendUserRowModel: Identifiable {
    let id: String
    let uid: String?
    let displayName: String
    let subText: String
    let status: FriendStatus?
    let activeDuoWorldId: String?

    func withStatus(_ status: FriendStatus) -> FriendUserRowModel {
        .init(
            id: id,
            uid: uid,
            displayName: displayName,
            subText: subText,
            status: status,
            activeDuoWorldId: activeDuoWorldId
        )
    }
}
