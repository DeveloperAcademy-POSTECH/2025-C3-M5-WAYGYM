//
//  FriendView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import SwiftUI
import FirebaseAuth

struct FriendView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var friendStore: FriendStore
    @EnvironmentObject private var userStore: UserStore
    @StateObject private var vm = FriendViewModel()
    private let userRepository = UserRepository()
    private let friendRepository = FriendRepository()

    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var isSearchLoading: Bool = false

    @State private var searchResults: [FriendUserRowModel] = []
    @State private var friends: [FriendUserRowModel] = []
    private var incomingRequestCount: Int { friendStore.incomingPendingUids.count }

    var body: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(title: "친구")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let errorMessage = friendStore.lastRefreshError {
                        refreshErrorBanner(message: errorMessage)
                    }
                    searchUser

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        friendList
                    } else {
                        searchResultList
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
        }
        .task {
            await userStore.refresh()
            await friendStore.refresh()
        }
        .task(id: friendStore.friendUids) {
            await fetchFriendProfiles()
        }
        .onReceive(friendStore.$incomingWorldRequestUids) { _ in
            sortFriends()
        }
        .onReceive(friendStore.$outgoingWorldRequestUids) { _ in
            sortFriends()
        }
        .onReceive(friendStore.$activeDuoOpponentUid) { _ in
            sortFriends()
        }
        .padding(.horizontal, 16)
        .background {
            Color.gangBgPrimary5
                .ignoresSafeArea()
        }
        .backHiddenSwipeEnabled()
        .dismissKeyboard()
    }

    // MARK: - UI
    private var searchUser: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                sectionTitle("유저 검색")
                helperText("이름이나 아이디로 검색해서 친구 신청을 보낼 수 있어요")
            }
            searchField
            
            Button {
                coordinator.push(.friendRequest)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("나에게 온 친구 신청")
                            .font(.text01)
                            .foregroundStyle(Color.gangText1)

                        Text(incomingRequestCount == 0 ? "새로운 신청이 없어요" : "\(incomingRequestCount)개의 신청이 있어요")
                            .font(.text02)
                            .foregroundStyle(Color.gangText2)
                    }

                    Spacer(minLength: 0)

                    if incomingRequestCount > 0 {
                        Text("\(incomingRequestCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.85))
                            )
                    }

                    if incomingRequestCount > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.gangText2.opacity(0.75))
                    }
                }
                .padding(14)
                .background(cardBackground)
                .overlay(cardBorder)
            }
            .buttonStyle(.plain)
            .disabled(incomingRequestCount == 0)
        }
    }

    private func refreshErrorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))

            Text("친구 정보를 불러오지 못했어요")
                .font(.text02)
                .foregroundStyle(Color.gangText1)

            Spacer(minLength: 0)

            Button {
                Task { await friendStore.refresh() }
            } label: {
                Text("재시도")
                    .font(.text02)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .accessibilityLabel("친구 정보 로드 실패. 재시도 버튼.")
    }
    
    private var friendList: some View {
        VStack(spacing: 10) {
            sectionTitle("친구 목록")

            if friends.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(friends) { friend in
                        friendRow(friend)
                    }
                }
            }
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.gangText2.opacity(0.9))

            TextField(
                "",
                text: $query,
                prompt: Text("닉네임 또는 친구코드")
                    .foregroundStyle(Color.white.opacity(0.5))
            )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(Color.gangText1)
                .font(.text01)
                .submitLabel(.search)
                .onSubmit {
                    tapSearch()
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    isSearching = false
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gangText2.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            Button {
                tapSearch()
            } label: {
                Text("검색")
                    .font(.text02)
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var searchResultList: some View {
        VStack(spacing: 10) {
            if isSearchLoading {
                ProgressView()
                    .foregroundStyle(Color.gang_text_2)
                    .frame(width: 50)
            } else if searchResults.isEmpty, isSearching {
                helperText("검색 결과가 없어요")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(searchResults) { user in
                    searchResultRow(user)
                }
            }
        }
        .padding(.top, 2)
    }
    
    // MARK: - UI Components
    private func searchResultRow(_ user: FriendUserRowModel) -> some View {
        let status = user.status ?? .canRequest

        return HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.title03)
                    .foregroundStyle(Color.gangText1)
                    .lineLimit(1)

                Text(user.subText)
                    .font(.text02)
                    .foregroundStyle(Color.gangText2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            statusButton(status: status, uid: user.uid)
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private func friendRow(_ friend: FriendUserRowModel) -> some View {
        let isMyOpponent = friend.uid == friendStore.activeDuoOpponentUid

        return HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.title03)
                    .foregroundStyle(Color.gangText1)
                    .lineLimit(1)

                Text(friend.subText)
                    .font(.text02)
                    .foregroundStyle(Color.gangText2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let uid = friend.uid,
               friendStore.activeDuoOpponentUid == uid {
                Text("경쟁전 플레이 중")
                    .font(.text02)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.red.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.red.opacity(0.8), lineWidth: 1)
                    )
            } else if let uid = friend.uid,
                      friendStore.incomingWorldRequestUids.contains(uid) {
                Button {
                    acceptWorldRequest(fromUid: uid)
                } label: {
                    Text("경쟁전 수락")
                        .font(.text02)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.gang_highlight_2.opacity(0.55))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.gang_highlight_2.opacity(0.65), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else if let uid = friend.uid,
                      friendStore.outgoingWorldRequestUids.contains(uid) {
                Text("경쟁전 신청중")
                    .font(.text02)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gangText2.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
//                    .background(
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .fill(Color.white.opacity(0.08))
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
//                    )
            } else if friend.activeDuoWorldId != nil {
                Text("경쟁전 플레이 중")
                    .font(.text02)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gangText2.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
//                    .background(
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .fill(Color.white.opacity(0.08))
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
//                    )
            } else {
                Button {
                    sendWorldRequest(toUid: friend.uid)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                        
                        Text("경쟁전 신청하기")
                            .font(.text02)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.red.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.red.opacity(0.8), lineWidth: 1)
                    )
                    
                }
                .buttonStyle(.plain)
                .disabled(friend.activeDuoWorldId != nil || friendStore.activeDuoOpponentUid == friend.uid)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay {
            if isMyOpponent {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.8), lineWidth: 1)
            } else {
                cardBorder
            }
        }
    }
    
    private func statusButton(status: FriendStatus, uid: String?) -> some View {
        let title: String
        let isEnabled: Bool
        let fill: Color
        let stroke: Color
        let textColor: Color

        switch status {
        case .alreadyFriend:
            title = "친구"
            isEnabled = false
            fill = Color.white.opacity(0.10)
            stroke = Color.white.opacity(0.08)
            textColor = Color.gangText2
        case .outgoingPending:
            title = "요청중"
            isEnabled = false
            fill = Color.gang_highlight_3.opacity(0.22)
            stroke = Color.gang_highlight_3.opacity(0.20)
            textColor = Color.white.opacity(0.90)
        case .incomingPending:
            title = "수락하기"
            isEnabled = true
            fill = Color.gang_highlight_2.opacity(0.4)
            stroke = Color.gang_highlight_2.opacity(0.4)
            textColor = Color.white
        case .canRequest:
            title = "친구신청"
            isEnabled = true
            fill = Color.white.opacity(0.18)
            stroke = Color.white.opacity(0.16)
            textColor = Color.white.opacity(0.92)
        }

        return Button {
            if isEnabled {
                switch status {
                case .canRequest:
                    sendFriendRequest(toUid: uid)
                case .incomingPending:
                    guard let fromUid = uid,
                          let toUid = Auth.auth().currentUser?.uid else { return }
                    Task {
                        do {
                            try await vm.acceptRequest(fromUid: fromUid, toUid: toUid)
                            await friendStore.refresh()
                            await MainActor.run {
                                updateSearchResultStatus(uid: fromUid, status: .alreadyFriend)
                            }
                        } catch {
                            print("⚠️ acceptFriendRequest 실패: \(error.localizedDescription)")
                        }
                    }
                default:
                    break
                }
            }
        } label: {
            Text(title)
                .font(.text02)
                .foregroundStyle(textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("아직 친구가 없어요")
                .font(.title03)
                .foregroundStyle(Color.gangText1)

            Text("유저를 검색해서 친구 신청을 보내보세요")
                .font(.text02)
                .foregroundStyle(Color.gangText2)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title03)
            .foregroundStyle(Color.gangText1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func helperText(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.text02)
                .foregroundStyle(Color.gangText2.opacity(0.7))
            Spacer()
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            Image(systemName: "person.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .frame(width: 42, height: 42)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .foregroundStyle(Color.black.opacity(0.18))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 1)
    }

    // MARK: - Actions
    private func tapSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }

        isSearching = true
        searchResults = []
        isSearchLoading = true

        Task {
            do {
                let users = try await userRepository.searchUsers(matching: trimmed)
                let rows = users.map { makeRow(from: $0) }
                await MainActor.run {
                    searchResults = rows
                    isSearchLoading = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearchLoading = false
                }
            }
        }
    }
    
    private func sendFriendRequest(toUid: String?) {
        guard let fromUid = Auth.auth().currentUser?.uid else { return }
        guard let toUid, toUid.isEmpty == false else { return }
        guard fromUid != toUid else { return }

        Task {
            do {
                try await friendRepository.sendFriendRequest(fromUid: fromUid, toUid: toUid)
                await MainActor.run {
                    friendStore.markOutgoingPending(uid: toUid)
                    updateSearchResultStatus(uid: toUid, status: .outgoingPending)
                }
            } catch {
                // TODO: handle error if UI needs to react
            }
        }
    }

    private func sendWorldRequest(toUid: String?) {
        guard let fromUid = Auth.auth().currentUser?.uid else { return }
        guard let toUid, toUid.isEmpty == false else { return }
        guard fromUid != toUid else { return }

        Task {
            await friendStore.markOutgoingWorldRequest(uid: toUid)
            do {
                try await friendRepository.sendWorldRequest(fromUid: fromUid, toUid: toUid)
                await friendStore.refresh()
                await userStore.refresh()
            } catch {
                await friendStore.unmarkOutgoingWorldRequest(uid: toUid)
                // TODO: handle error if UI needs to react
            }
        }
    }

    private func acceptWorldRequest(fromUid: String?) {
        guard let toUid = Auth.auth().currentUser?.uid else { return }
        guard let fromUid, fromUid.isEmpty == false else { return }
        guard fromUid != toUid else { return }

        Task {
            await friendStore.markAcceptedWorldRequest(uid: fromUid)
            do {
                try await friendRepository.acceptWorldRequest(fromUid: fromUid, toUid: toUid)
                await friendStore.refresh()
                await userStore.refresh()
            } catch {
                await friendStore.restoreIncomingWorldRequest(uid: fromUid)
                print("⚠️ acceptWorldRequest 실패: \(error.localizedDescription)")
            }
        }
    }

    private func makeRow(from user: User) -> FriendUserRowModel {
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
        let status = user.id.flatMap { friendStore.status(for: $0) }
        return .init(
            id: id,
            uid: user.id,
            displayName: displayName,
            subText: subText,
            status: status,
            activeDuoWorldId: user.activeDuoWorldId
        )
    }

    private func updateSearchResultStatus(uid: String, status: FriendStatus) {
        for index in searchResults.indices {
            if searchResults[index].uid == uid {
                searchResults[index] = searchResults[index].withStatus(status)
            }
        }
    }

    private func fetchFriendProfiles() async {
        let uids = Array(friendStore.friendUids)
        guard uids.isEmpty == false else {
            await MainActor.run { friends = [] }
            return
        }

        var fetched: [FriendUserRowModel] = []
        await withTaskGroup(of: FriendUserRowModel?.self) { group in
            for uid in uids {
                group.addTask {
                    do {
                        let profile = try await userRepository.fetchUserProfile(uid: uid)
                        return await makeRow(from: profile)
                    } catch {
                        return nil
                    }
                }
            }

            for await row in group {
                if let row {
                    fetched.append(row)
                }
            }
        }

        await MainActor.run {
            friends = fetched
            sortFriends()
        }
    }

    private func sortFriends() {
        guard friends.isEmpty == false else { return }

        let incoming = friendStore.incomingWorldRequestUids
        let outgoing = friendStore.outgoingWorldRequestUids
        let activeOpponentUid = friendStore.activeDuoOpponentUid

        func priority(for uid: String?) -> Int {
            guard let uid else { return 3 }
            if activeOpponentUid == uid { return 0 }
            if incoming.contains(uid) { return 1 }
            if outgoing.contains(uid) { return 2 }
            return 3
        }

        friends.sort { lhs, rhs in
            let lp = priority(for: lhs.uid)
            let rp = priority(for: rhs.uid)
            if lp != rp { return lp < rp }

            let nameOrder = lhs.displayName.localizedStandardCompare(rhs.displayName)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return (lhs.uid ?? lhs.id) < (rhs.uid ?? rhs.id)
        }
    }
}

// MARK: - Local Model (UI only)
private struct FriendUserRowModel: Identifiable {
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

#Preview("FriendView") {
    FriendView()
        .environmentObject(AppCoordinator())
        .environmentObject(FriendStore())
        .font(.text01)
        .foregroundColor(Color("gang_text_2"))
        .preferredColorScheme(.dark)
}

#Preview("FriendView - Refresh Error") {
    FriendView()
        .environmentObject(AppCoordinator())
        .environmentObject(FriendStore.previewWithError("친구 정보를 불러오지 못했어요"))
        .font(.text01)
        .foregroundColor(Color("gang_text_2"))
        .preferredColorScheme(.dark)
}
