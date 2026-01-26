//
//  SettingView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI
import FirebaseAuth

struct SettingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var userStore: UserStore
    @AppStorage("selectedWeaponId") private var selectedWeaponId: String = "0"
    
    private var phoneNumberText: String {
        Auth.auth().currentUser?.phoneNumber ?? "전화번호 미설정"
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(title: "설정")
            
            profileCard
                .padding(.top, 12)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
                .padding(.vertical, 16)
            
            VStack(spacing: 14) {
                settingRow(title: "Privacy Policy") {
                    // TODO: coordinator.push(.privacyPolicy) or open URL
                }

                settingRow(title: "Contact us") {
                    // TODO: coordinator.push(.contact) or open mail composer
                }

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .padding(.vertical, 6)

                settingRow(title: "로그아웃", showsChevron: false) {
                    do {
                        try Auth.auth().signOut()
                        selectedWeaponId = "0"
                        coordinator.replaceRoot(.auth)
                    } catch {
                        print("[Logout Error]", error.localizedDescription)
                    }
                }
            }

            Spacer(minLength: 20)

            Button {
                // TODO: 회원탈퇴 플로우 연결 (confirm sheet -> delete user)
            } label: {
                Text("회원탈퇴")
                    .underline()
                    .font(.text02)
                    .foregroundStyle(Color.gangText2.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            
        }
        .padding(.horizontal, 16)
        .background {
            Color.gangBgPrimary5
                .ignoresSafeArea()
        }
        .backHiddenSwipeEnabled()
    }
    
    private var profileCard: some View {
        Button {
            coordinator.push(.profileEdit)
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .foregroundStyle(Color.white.opacity(0.10))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )

                    Image("profile")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 55)
                        .padding(.leading, 4)
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 10) {
                    Text(userStore.profile?.displayName ?? "사용자")
                        .font(.title02)
                        .foregroundStyle(Color.gangText1)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(userStore.profile?.homeArea ?? "주소 미설정")
                            .lineLimit(1)

                        Text(phoneNumberText)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.gangText2)
                    .font(.text02)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.gangText2.opacity(0.9))
                    .padding(.trailing, 2)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func settingRow(title: String, showsChevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.text02)
                    .foregroundStyle(Color.gangText2)

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.gangText2.opacity(0.7))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingView()
        .environmentObject(AppCoordinator())
        .environmentObject(UserStore())
        .font(.text01)
        .foregroundColor(Color("gang_text_2"))
}
