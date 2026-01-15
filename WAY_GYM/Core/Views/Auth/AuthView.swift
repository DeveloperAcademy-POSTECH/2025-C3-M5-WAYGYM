//
//  AuthView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel

    private enum FocusField: Hashable {
        case phone
        case code
    }

    @FocusState private var focusField: FocusField?

    init(onAuthed: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(onAuthed: onAuthed))
    }

    var body: some View {
        ZStack {
            Color.gang_bg_profile
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            countryRow
                                .customBorder(color: .gangBlackOpacity)
                            
                            phoneField
                        }
                        
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.red.opacity(0.9))
                        }
                        
                        CustomButton(
                            title: viewModel.isSending ? "전송 중..." : "인증번호 보내기",
                            action: { Task { await viewModel.sendCode() } },
                            isDisabled: !viewModel.canSend || viewModel.verificationID != nil
                        )
                    }
                }

                if viewModel.verificationID != nil {
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("6자리 인증번호", text: $viewModel.codeText)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .padding(18)
                                .background(Color.gangText2)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(Color.gangBlack)
                                .focused($focusField, equals: .code)
                                .onChange(of: viewModel.codeText) { _, newValue in
                                    viewModel.onCodeTextChanged(newValue)
                                }
                            
                            CustomButton(
                                title: "확인",
                                action: { Task { await viewModel.verifyCode() } },
                                isDisabled: !viewModel.canVerify,
                                isLoading: viewModel.isVerifying
                            )
                            
                            Text("전화번호 다시 입력")
                                .underline()
                                .font(.text02)
                                .foregroundStyle(Color.gang_bg_w_opacity)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .onTapGesture {
                                    viewModel.resetToPhoneEntry()
                                }
                        }
                    }
                }

                Spacer(minLength: 10)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
        }
        .onChange(of: focusField) { _, newValue in
            if newValue == .phone, viewModel.verificationID != nil {
                viewModel.resetToPhoneEntry()
            }
        }
        .sheet(isPresented: $viewModel.showCountrySheet) {
            CountryPickerSheet(selected: viewModel.country) { selected in
                // 닫기 버튼으로 현재 선택 유지하는 케이스도 있으니 방어
                viewModel.selectCountry(selected)
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
            viewModel.tapCountryRow()
        } label: {
            HStack {
                Text(viewModel.country.flag).font(.title3)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Color.gangText2)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gangBlackOpacity, lineWidth: 1)
            )
        }
    }

    private var phoneField: some View {
        TextField(viewModel.isKR ? "010-1234-5678" : "전화번호", text: $viewModel.phoneText)
            .keyboardType(.numberPad)
            .textContentType(.telephoneNumber)
            .textFieldStyle(.plain)
            .padding(12)
            .background(Color.gangText2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(Color.gangBlack)
            .focused($focusField, equals: .phone)
            .onChange(of: viewModel.phoneText) { _, newValue in
                viewModel.onPhoneTextChanged(newValue)
            }
    }
}

struct AppCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(Color.gangBgWOpacity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}


#Preview {
    AuthView(onAuthed: {
        // preview authed
    })
    .font(.text01)
    .foregroundColor(Color("gang_text_2"))
}
