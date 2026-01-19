//
//  FriendRequestView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import SwiftUI
import FirebaseAuth

struct FriendRequestView: View {
    @EnvironmentObject private var friendStore: FriendStore
    private let userRepository = UserRepository()
    private let friendRepository = FriendRepository()

    @State private var requests: [FriendRequestRowModel] = []
    @State private var isLoading: Bool = false
    private let isPreview: Bool

    init() {
        isPreview = false
    }

    fileprivate init(previewRequests: [FriendRequestRowModel]) {
        _requests = State(initialValue: previewRequests)
        _isLoading = State(initialValue: false)
        isPreview = true
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(title: "친구 요청")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .tint(Color.white.opacity(0.8))
                            .padding(.top, 24)
                    } else if requests.isEmpty {
                        emptyState
                    } else {
                        ForEach(requests) { request in
                            requestRow(request)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 16)
        }
        .background {
            Color.gangBgPrimary5
                .ignoresSafeArea()
        }
        .backHiddenSwipeEnabled()
        .task {
            if !isPreview {
                await loadRequests()
            }
        }
    }

    private func requestRow(_ request: FriendRequestRowModel) -> some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.title03)
                    .foregroundStyle(Color.gangText1)
                    .lineLimit(1)

                Text(request.subText)
                    .font(.text02)
                    .foregroundStyle(Color.gangText2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                acceptRequest(request)
            } label: {
                Text("수락")
                    .font(.text02)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gang_highlight_2.opacity(0.30))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gang_highlight_2.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("친구 요청이 없어요")
                .font(.title03)
                .foregroundStyle(Color.gangText1)

            Text("새로운 친구 신청이 도착하면 여기에 보여요")
                .font(.text02)
                .foregroundStyle(Color.gangText2)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(cardBackground)
        .overlay(cardBorder)
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

    private func loadRequests() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            await MainActor.run { requests = [] }
            return
        }

        await MainActor.run { isLoading = true }
        do {
            let pending = try await friendRepository.fetchPendingFriendRequestsReceived(to: uid)
            var fetched: [FriendRequestRowModel] = []
            await withTaskGroup(of: FriendRequestRowModel?.self) { group in
                for request in pending {
                    guard let requestId = request.id else { continue }
                    group.addTask {
                        do {
                            let profile = try await userRepository.fetchUserProfile(uid: request.fromUid)
                            return makeRow(requestId: requestId, fromUid: request.fromUid, profile: profile)
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

            fetched.sort { $0.displayName < $1.displayName }
            await MainActor.run {
                requests = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run {
                requests = []
                isLoading = false
            }
        }
    }

    private func makeRow(requestId: String, fromUid: String, profile: UserProfile) -> FriendRequestRowModel {
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

    private func acceptRequest(_ request: FriendRequestRowModel) {
        guard let toUid = Auth.auth().currentUser?.uid else { return }

        Task {
            do {
                try await friendRepository.acceptFriendRequest(
                    requestId: request.requestId,
                    fromUid: request.fromUid,
                    toUid: toUid
                )
                await MainActor.run {
                    requests.removeAll { $0.id == request.id }
                }
                await friendStore.refresh()
            } catch {
                // TODO: handle error if UI needs to react
            }
        }
    }
}

private struct FriendRequestRowModel: Identifiable {
    let id: String
    let requestId: String
    let fromUid: String
    let displayName: String
    let subText: String
}

#Preview("FriendRequestView - Mock Data") {
    FriendRequestView(previewRequests: [
        .init(id: "req-1", requestId: "req-1", fromUid: "uid-1", displayName: "루트", subText: "포항시 북구"),
        .init(id: "req-2", requestId: "req-2", fromUid: "uid-2", displayName: "조이드", subText: "z0id"),
        .init(id: "req-3", requestId: "req-3", fromUid: "uid-3", displayName: "커비", subText: "서울 성수"),
    ])
    .environmentObject(AppCoordinator())
    .environmentObject(FriendStore())
}
