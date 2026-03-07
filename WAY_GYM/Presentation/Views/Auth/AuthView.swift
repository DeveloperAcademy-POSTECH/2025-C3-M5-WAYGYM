//
//  AuthView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var vm = AuthViewModel()

    private enum FocusField: Hashable {
        case phone
        case code
    }

    @FocusState private var focusField: FocusField?

    var body: some View {
        ZStack {
            Color.gang_bg_profile
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                InputCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            countryRow
                                .customBorder(color: .gangBlackOpacity)
                            
                            TextField(vm.isKR ? "010-1234-5678" : "전화번호", text: $vm.phoneText)
                                .keyboardType(.numberPad)
                                .textContentType(.telephoneNumber)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.gangText2)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(Color.gangBlack)
                                .focused($focusField, equals: .phone)
                                .onChange(of: vm.phoneText) { _, newValue in
                                    vm.onPhoneTextChanged(newValue)
                                }
                        }
                        
                        if vm.verificationID == nil, let errorMessage = vm.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.red.opacity(0.9))
                        }
                        
                        CustomButton(
                            title: vm.isSending ? "전송 중..." : "인증번호 보내기",
                            action: { Task { await
                                vm.sendCode() } },
                            style: .compact,
                            isDisabled: !vm.canSend || vm.verificationID != nil
                        )
                    }
                }

                if vm.verificationID != nil {
                    InputCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("6자리 인증번호", text: $vm.codeText)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .padding(12)
                                .background(Color.gangText2)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(Color.gangBlack)
                                .focused($focusField, equals: .code)
                                .onChange(of: vm.codeText) { _, newValue in
                                    vm.onCodeTextChanged(newValue)
                                }
                            
                            CustomButton(
                                title: "확인",
                                action: { Task { await vm.verifyCode() } },
                                style: .compact,
                                isDisabled: !vm.canVerify || vm.isCompletingAuth,
                                isLoading: vm.isVerifying || vm.isCompletingAuth
                            )
                            
                            if let errorMessage = vm.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.red.opacity(0.9))
                            }
                            
                            Text("전화번호 다시 입력")
                                .underline()
                                .font(.text02)
                                .foregroundStyle(Color.gangText2.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .onTapGesture {
                                    vm.resetToPhoneEntry()
                                }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
        }
        .dismissKeyboard()
        .onChange(of: focusField) { _, newValue in
            if newValue == .phone, vm.verificationID != nil {
                vm.resetToPhoneEntry()
            }
        }
        .sheet(isPresented: $vm.showCountrySheet) {
            CountryPickerSheet(selected: vm.country) { selected in
                vm.selectCountry(selected)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("동네접수RUN")
                .font(.largeTitle01)

            Text("전화번호 인증으로 빠르게 시작해요")
                .font(.text01)
        }
        .foregroundStyle(Color.gangText1)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var countryRow: some View {
        Button {
            vm.tapCountryRow()
        } label: {
            HStack {
                Text(vm.country.flag).font(.title3)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Color.gangText2)
            }
            .padding(12)
            .customBorder(color: Color.gangBlackOpacity)
        }
    }
}


#Preview {
    AuthView()
    .font(.text01)
    .foregroundColor(Color("gang_text_2"))
}
