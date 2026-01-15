//
//  ProfileSetupView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI

struct ProfileSetupView: View {
    @StateObject private var vm = ProfileSetupViewModel()

    var body: some View {
        ZStack {
            Color.gangBgPrimary5
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("초기 프로필 설정")
                    .font(.largeTitle02)
                    .padding(.top, 18)

                VStack(spacing: 12) {
                    Group {
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

                    sectionTitle("주소")
                    inputCard {
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
                            // 모드 변경 시 UX: 자동모드면 한 번 시도해주기
                            if vm.addressMode == .current && vm.fullAddressText.isEmpty {
                                vm.tapUseCurrentLocation()
                            }
                        }
                        .onAppear {
                            vm.tapUseCurrentLocation() // 첫 진입 자동으로 현위치 시도
                        }

                        if let err = vm.addressError {
                            errorText(err)
                        }
                    }

                    sectionTitle("아이디")
                    inputCard {
                        HStack(spacing: 10) {
                            VStack {
                                TextField("", text: $vm.userId,
                                          prompt: Text("예) gang_run.01").foregroundStyle(Color.gangText2.opacity(0.6)))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.text01)
                                    .foregroundStyle(Color.gangText1)
                                    .onChange(of: vm.userId) {
                                        vm.validateUserId()
                                    }
                                    .simultaneousGesture(TapGesture().onEnded {
                                        vm.resetUserIdCheckState()
                                    })
                                
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
                            Text("규칙: 3~10자, 영문/숫자/특수문자(._-)")
                                .font(.text02)
                                .foregroundStyle(Color.gangText2.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
                
                CustomButton(title: "시작하기", action: { vm.saveProfileToFireStore() }, isDisabled: !vm.canSubmit || vm.canSubmit)
                    .padding(.horizontal, 16)
                
                // TODO: 팝업창으로 바꾸기
                if let saveErr = vm.saveProfileError {
                    errorText(saveErr)
                }
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $vm.isAddressPickerPresented) {
            AddressPickerSheet(data: vm.addressData) { s, g, d in
                vm.sido = s
                vm.sigungu = g
                vm.dong = d
                vm.validateAddress()
            }
            .presentationDetents([.fraction(0.45)])
        }
        .onChange(of: vm.nickname) { vm.validateNickname() }
        .onChange(of: vm.userId) { vm.validateUserId() }
        .onChange(of: vm.sido) { vm.validateAddress() }
        .onChange(of: vm.sigungu) { vm.validateAddress() }
        .onChange(of: vm.dong) { vm.validateAddress() }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title03)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
    
    private func inputCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
        )
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
