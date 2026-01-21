//
//  ProfileEditView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var userStore: UserStore
    @StateObject private var vm = ProfileEditViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(title: "프로필 수정")
            
            VStack(spacing: 20) {
                VStack {
                    sectionTitle("이름/닉네임")
                    TextField("이름 입력", text: $vm.nickname)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gangText2)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(Color.gangBlack)
                        .onChange(of: vm.nickname) {
                            vm.validateNickname()
                        }

                    if let err = vm.nicknameError {
                        errorText(err)
                    }
                }

                VStack {
                    sectionTitle("성별")
                    InputCard {
                        HStack(spacing: 10) {
                            ForEach(ProfileSetupViewModel.Sex.allCases, id: \.self) { s in
                                Button {
                                    vm.sex = s
                                    vm.validateSex()
                                } label: {
                                    Text(s.displayName)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(vm.sex == s ? Color.white.opacity(0.22) : Color.black.opacity(0.18))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(vm.sex == s ? Color.white.opacity(0.55) : Color.white.opacity(0.18), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let err = vm.sexError {
                            errorText(err)
                        }
                    }
                }

                VStack(alignment: .leading) {
                    sectionTitle("주소")
                    Text("주로 땅따먹기를 진행할 지역을 설정해주세요")
                        .font(.text02)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.vertical, 1)
                    InputCard {
                        Picker("", selection: $vm.addressMode) {
                            ForEach(ProfileSetupViewModel.AddressMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 10) {
                            Text(vm.fullAddressText.isEmpty ? "주소가 설정되지 않았습니다" : vm.fullAddressText)
                                .font(.text01)
                                .foregroundStyle(vm.fullAddressText.isEmpty ? Color.gangText2.opacity(0.6) : Color.gangText1)
                                .lineLimit(1)

                            Spacer()

                            if vm.addressMode == .current {
                                CustomButton(title: "내위치", action: { vm.tapUseCurrentLocation() }, style: .small, systemImage: "location")
                            } else {
                                CustomButton(title: "선택", action: { vm.isAddressPickerPresented = true }, style: .small)
                            }
                        }
                        .onChange(of: vm.addressMode) {
                            if vm.addressMode == .current {
                                vm.tapUseCurrentLocation()
                            }
                        }

                        if let err = vm.addressError {
                            errorText(err)
                        }
                    }
                }

                HStack {
                    sectionTitle("아이디")
                    Spacer()
                    Text(vm.userId.isEmpty ? "아이디 미설정" : vm.userId)
                        .font(.text01)
                        .foregroundStyle(vm.userId.isEmpty ? Color.gangText2.opacity(0.6) : Color.gangText1)
                }
            }
            .padding(.top, 16)

            Spacer(minLength: 12)

            CustomButton(
                title: "수정하기",
                action: {
                    vm.saveProfileToFirestore {
                        Task {
                            await userStore.refresh()
                            await MainActor.run {
                                coordinator.pop()
                            }
                        }
                    }
                },
                isDisabled: !vm.canSave || vm.isSavingProfile,
                isLoading: vm.isSavingProfile
            )

            if let saveErr = vm.saveProfileError {
                errorText(saveErr)
            }
        }
        .padding(.horizontal, 16)
        .background {
            Color.gangBgPrimary5
                .ignoresSafeArea()
        }
        .dismissKeyboard()
        .backHiddenSwipeEnabled()
        .onReceive(userStore.$profile) { profile in
            vm.loadProfileIfNeeded(profile)
        }
        .sheet(isPresented: $vm.isAddressPickerPresented) {
            AddressPickerSheet(
                data: vm.addressData,
                initialSido: vm.sido,
                initialSigungu: vm.sigungu,
                initialDong: vm.dong
            ) { s, g, d in
                vm.sido = s
                vm.sigungu = g
                vm.dong = d
                vm.validateAddress()
            }
            .presentationDetents([.fraction(0.45)])
        }
    }
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title03)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(.text02)
            .foregroundStyle(Color.red.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(UserStore())
        .font(.text01)
        .foregroundColor(Color("gang_text_2"))
}
