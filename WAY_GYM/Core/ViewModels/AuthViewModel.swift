//
//  AuthViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import Foundation
import FirebaseAuth

final class AuthViewModel: ObservableObject {
    @Published var country: Country = CountryData.korea
    @Published var showCountrySheet: Bool = false
    
    @Published var phoneText: String = "" /// 사용자에게 보이는 값(한국: 010-1234-5678)
    @Published var codeText: String = "" /// 6자리 인증번호
    @Published var verificationID: String? = nil /// Firebase에서 받은 verificationID

    @Published var isSending: Bool = false
    @Published var isVerifying: Bool = false
    @Published var isCompletingAuth: Bool = false
    @Published var errorMessage: String? = nil

    var isKR: Bool { country.id == "KR" }
    var canSend: Bool {
        if isSending { return false }
        if isKR { return PhoneKR.isValidKR(phoneText) }
        // 해외는 MVP: 최소 6자리 이상이면 보내기 활성화(추후 PhoneNumberKit로 강화 권장)
        return phoneText.filter(\.isNumber).count >= 6
    }
    var canVerify: Bool {
        if isVerifying { return false }
        return verificationID != nil && codeText.count == 6
    }

    func tapCountryRow() {
        showCountrySheet = true
    }

    func selectCountry(_ selected: Country) {
        country = selected
        showCountrySheet = false

        // 국가 바꾸면 입력 UX 초기화
        phoneText = ""
        verificationID = nil
        codeText = ""
        errorMessage = nil
    }

    func onPhoneTextChanged(_ newValue: String) {
        errorMessage = nil

        if isKR {
            let digits = PhoneKR.digitsOnly(newValue)
            let limited = String(digits.prefix(11))
            phoneText = PhoneKR.formatKR(limited)
        } else {
            // 다른 국가는 MVP로 숫자만 제한(최대 15 정도)
            phoneText = newValue.filter(\.isNumber).prefix(15).map(String.init).joined()
        }
    }

    func onCodeTextChanged(_ newValue: String) {
        codeText = newValue.filter(\.isNumber).prefix(6).map(String.init).joined()
    }

    func resetToPhoneEntry() {
        verificationID = nil
        codeText = ""
        errorMessage = nil
    }

    func sendCode() async {
        errorMessage = nil
        isSending = true
        defer { isSending = false }

        let e164: String?
        if isKR {
            e164 = PhoneKR.toE164KR(phoneText)
            if e164 == nil {
                errorMessage = "010으로 시작하는 11자리 숫자 형식으로 입력해 주세요."
                return
            }
        } else {
            let digits = phoneText.filter(\.isNumber)
            e164 = country.dialCode + digits
        }

        guard let phoneNumber = e164 else { return }

        do {
            let id: String = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                    if let error {
                        cont.resume(throwing: error)
                        return
                    }

                    guard let verificationID, !verificationID.isEmpty else {
                        cont.resume(throwing: NSError(
                            domain: "AuthViewModel",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Empty verificationID"]
                        ))
                        return
                    }

                    cont.resume(returning: verificationID)
                }
            }

            self.verificationID = id
        } catch {
            errorMessage = "인증번호 전송에 실패했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        }
    }

    func verifyCode() async {
        guard let verificationID else { return }

        errorMessage = nil

        // 로딩 플래그 초기화/정리: 어떤 경로로 빠져나가도 spinner가 내려가도록 보장
        isVerifying = true
        defer { isVerifying = false }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: codeText
        )

        do {
            _ = try await Auth.auth().signIn(with: credential)
            isCompletingAuth = true
        } catch {
            errorMessage = "인증번호가 올바르지 않아요. 다시 확인해 주세요."
        }
    }
}
