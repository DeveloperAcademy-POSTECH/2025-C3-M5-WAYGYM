//
//  ProfileSetupView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var userStore: UserStore
    @StateObject private var vm = ProfileSetupViewModel()

    var body: some View {
        VStack {
            header

            ScrollView {
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
                                Text(err)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.red)
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
                            .onAppear {
                                vm.tapUseCurrentLocation() // 첫 진입 자동으로 현위치 시도
                            }
                            .onChange(of: vm.addressMode) {
                                // 모드 변경 시 UX: 자동모드면 한 번 시도해주기
                                if vm.addressMode == .current && vm.fullAddressText.isEmpty {
                                    vm.tapUseCurrentLocation()
                                }
                            }
                            if let err = vm.addressError {
                                errorText(err)
                            }
                        }
                    }

                    VStack(alignment: .leading) {
                        sectionTitle("아이디")
                        Text("아이디는 설정 후 나중에 변경할 수 없어요")
                            .font(.text02)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.vertical, 1)
                        InputCard {
                            HStack(spacing: 10) {
                                VStack {
                                    TextField("", text: $vm.userId,
                                                prompt: Text("예) gang_run.01").foregroundStyle(Color.gangText2.opacity(0.6)))
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .font(.text01)
                                        .foregroundStyle(Color.gangText1)
                                        .onChange(of: vm.userId) {
                                            vm.resetUserIdCheckState()
                                            vm.validateUserIdFormat()
                                        }
                                    
                                    Rectangle()
                                        .frame(height: 1)
                                }
                                .foregroundColor(Color.gangText1)
                                
                                if vm.userIdChecked && vm.userIdAvailable {
                                    Text("완료")
                                        .font(.text02)
                                        .foregroundStyle(Color.success)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                } else {
                                    CustomButton(
                                        title: "중복확인",
                                        action: { vm.tapCheckUserId() },
                                        style: .small,
                                        isDisabled: vm.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                        isLoading: vm.isCheckingUserId
                                    )
                                }
                                
                            }

                            if let err = vm.userIdError {
                                errorText(err)
                            } else if vm.userIdChecked && vm.userIdAvailable {
                                Text("사용 가능한 아이디입니다")
                                    .font(.text02)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("규칙: 6~10자, 영문/숫자/특수문자(._-)")
                                    .font(.text02)
                                    .foregroundStyle(Color.gangText2.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }

            Spacer()
            
            CustomButton(
                title: "시작하기",
                action: {
                    vm.saveProfileToFirestore {
                        Task {
                            await userStore.refresh()
                            await MainActor.run {
                                coordinator.replaceRoot(.main)
                            }
                        }
                    }
                },
                isDisabled: !vm.canSubmit || vm.isSavingProfile,
                isLoading: vm.isSavingProfile
            )
            
            // TODO: 팝업창으로 바꾸기
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
    
    private var header: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("프로필 설정")
                .font(.largeTitle02)
            Text("닉네임/주소/아이디를 설정해 주세요.")
                .font(.text01)
                .foregroundStyle(Color.gang_text_2)
        }
        .padding(.vertical, 14)
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
    ProfileSetupView()
        .font(.text01)
        .foregroundColor(Color.gangText2)
}
