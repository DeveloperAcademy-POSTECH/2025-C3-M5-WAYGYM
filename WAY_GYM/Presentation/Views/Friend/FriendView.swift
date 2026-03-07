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

                    if vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        friendList
                    } else {
                        searchResultList
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .background {
            Color.gangBgPrimary5
                .ignoresSafeArea()
        }
        .backHiddenSwipeEnabled()
        .dismissKeyboard()
        .task {
            await userStore.refresh()
            await friendStore.refresh()
        }
        .task(id: friendStore.friendUids) {
            await vm.fetchFriendProfiles(friendStore: friendStore)
        }
        .onReceive(friendStore.$incomingWorldRequestUids) { _ in
            vm.sortFriends(friendStore: friendStore)
        }
        .onReceive(friendStore.$outgoingWorldRequestUids) { _ in
            vm.sortFriends(friendStore: friendStore)
        }
        .onReceive(friendStore.$activeDuoOpponentUid) { _ in
            vm.sortFriends(friendStore: friendStore)
        }
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

            if vm.friends.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.friends) { friend in
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
                text: $vm.query,
                prompt: Text("닉네임 또는 친구코드")
                    .foregroundStyle(Color.white.opacity(0.5))
            )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(Color.gangText1)
                .font(.text01)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        await vm.tapSearch { uid in
                            friendStore.status(for: uid)
                        }
                    }
                }

            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    vm.isSearching = false
                    vm.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gangText2.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task {
                    await vm.tapSearch { uid in
                        friendStore.status(for: uid)
                    }
                }
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
            if vm.isSearchLoading {
                ProgressView()
                    .foregroundStyle(Color.gang_text_2)
                    .frame(width: 50)
            } else if vm.searchResults.isEmpty, vm.isSearching {
                helperText("검색 결과가 없어요")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(vm.searchResults) { user in
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
                    Task {
                        await vm.acceptWorldRequest(
                            currentUid: Auth.auth().currentUser?.uid,
                            fromUid: uid,
                            friendStore: friendStore,
                            userStore: userStore
                        )
                    }
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
                    Task {
                        await vm.sendWorldRequest(
                            currentUid: Auth.auth().currentUser?.uid,
                            toUid: friend.uid,
                            friendStore: friendStore,
                            userStore: userStore
                        )
                    }
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
                    Task {
                        await vm.sendFriendRequest(
                            currentUid: Auth.auth().currentUser?.uid,
                            toUid: uid,
                            friendStore: friendStore
                        )
                    }
                case .incomingPending:
                    Task {
                        await vm.acceptIncomingFriendRequest(
                            currentUid: Auth.auth().currentUser?.uid,
                            fromUid: uid,
                            friendStore: friendStore
                        )
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
