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
    @StateObject private var vm: FriendRequestViewModel
    
    init(viewModel: FriendRequestViewModel = FriendRequestViewModel()) {
        _vm = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(title: "친구 요청")
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if vm.isLoading {
                        ProgressView()
                            .tint(Color.white.opacity(0.8))
                            .padding(.top, 24)
                    } else if vm.requests.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.requests) { request in
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
            await vm.loadRequests(currentUid: Auth.auth().currentUser?.uid)
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
                Task {
                    do {
                        try await vm.acceptRequest(
                            request,
                            currentUid: Auth.auth().currentUser?.uid,
                            friendStore: friendStore
                        )
                    } catch {
                        // TODO: 에러 팝업창
                    }
                }
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
}
