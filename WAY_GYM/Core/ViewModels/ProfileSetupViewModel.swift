//
//  ProfileSetupViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/15/26.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore


final class ProfileSetupViewModel: ObservableObject {
    enum Sex: String, CaseIterable {
        case male
        case female
        case other

        var displayName: String {
            switch self {
            case .male: return "남성"
            case .female: return "여성"
            case .other: return "이외"
            }
        }
    }

    @Published var sex: Sex? = nil
    @Published var sexError: String? = nil

    @Published var nickname: String = ""
    @Published var userId: String = ""

    @Published var sido: String = ""
    @Published var sigungu: String = ""
    @Published var dong: String = ""
    let addressData: [SidoNode]
    private let locationService = LocationAddressService()

    enum AddressMode: String, CaseIterable { case current = "현위치", manual = "직접 선택" }
    @Published var addressMode: AddressMode = .current
    @Published var isAddressPickerPresented: Bool = false

    @Published var nicknameError: String? = nil
    @Published var userIdError: String? = nil
    @Published var addressError: String? = nil

    @Published var isCheckingUserId: Bool = false
    @Published var userIdChecked: Bool = false
    @Published var userIdAvailable: Bool = false
    
    @Published var isSavingProfile: Bool = false
    @Published var saveProfileError: String? = nil

    init() {
        self.addressData = (try? AddressLoader.load3DepthJSON()) ?? []
    }

    var fullAddressText: String {
        [sido, sigungu, dong].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - Rules
    func validateNickname() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { nicknameError = "이름/닉네임을 입력해주세요."; return }
        if trimmed.count < 2 { nicknameError = "2글자 이상으로 입력해주세요."; return }
        nicknameError = nil
    }

    func validateSex() {
        if sex == nil {
            sexError = "성별을 선택해주세요."
        } else {
            sexError = nil
        }
    }

    func validateUserIdFormat() {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty { userIdError = "아이디를 입력해주세요."; return }
        if trimmed.count < 6 || trimmed.count > 20 { userIdError = "6~20자 범위로 입력해주세요."; return }

        let pattern = "^[A-Za-z0-9._-]+$"
        if trimmed.range(of: pattern, options: .regularExpression) == nil {
            userIdError = "영문/숫자/특수문자(._-)만 사용할 수 있습니다."
            return
        }

        userIdError = nil
    }
    
    func resetUserIdCheckState() {
        userIdChecked = false
        userIdAvailable = false
        isCheckingUserId = false
    }

    func validateAddress() {
        if fullAddressText.isEmpty {
            addressError = "주소를 설정해주세요."
        } else {
            addressError = nil
        }
    }

    var canSubmit: Bool {
        [
            nicknameError == nil,
            userIdError == nil,
            addressError == nil,
            sexError == nil,
            !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !fullAddressText.isEmpty,
            sex != nil,
            userIdChecked,
            userIdAvailable,
            !isCheckingUserId
        ].allSatisfy { $0 }
    }
    
}

// MARK: - Actions
extension ProfileSetupViewModel {
    func tapUseCurrentLocation() {
        Task {
            do {
                let loc = try await locationService.requestOneShotLocation()
                let addr = try await locationService.reverseGeocode(loc)
                await MainActor.run {
                    self.sido = addr.sido
                    self.sigungu = addr.sigungu
                    self.dong = addr.dong
                    self.validateAddress()
                }
            } catch {
                await MainActor.run {
                    self.addressError = "현위치 주소를 불러오지 못했습니다. 직접 선택으로 설정해주세요."
                }
            }
        }
    }

    func tapCheckUserId() {
        validateUserIdFormat()
        guard userIdError == nil else { return }

        let candidate = userId.trimmingCharacters(in: .whitespacesAndNewlines)

        isCheckingUserId = true
        userIdChecked = false
        userIdAvailable = false

        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db
                    .collection("Users")
                    .whereField("friendCode", isEqualTo: candidate)
                    .limit(to: 1)
                    .getDocuments()

                let available = snapshot.documents.isEmpty

                await MainActor.run {
                    self.userIdAvailable = available
                    self.userIdChecked = true
                    self.userIdError = available ? nil : "이미 사용 중인 아이디입니다."
                    self.isCheckingUserId = false
                }
            } catch {
                await MainActor.run {
                    self.userIdChecked = false
                    self.userIdAvailable = false
                    self.userIdError = "중복 확인에 실패했습니다. 다시 시도해주세요."
                    self.isCheckingUserId = false
                }
            }
        }
    }
    
    func saveProfileToFirestore(onSuccess: (() -> Void)? = nil) {
        guard !isSavingProfile else { return }
        
        print(
            "canSubmit:",
            "nicknameError:", nicknameError as Any,
            "userIdError:", userIdError as Any,
            "addressError:", addressError as Any,
            "sexError:", sexError as Any,
            "userIdChecked:", userIdChecked,
            "userIdAvailable:", userIdAvailable,
            "isCheckingUserId:", isCheckingUserId
        )
        
        saveProfileError = nil
        
        validateNickname()
        validateSex()
        validateAddress()
        
        guard canSubmit else {
            isSavingProfile = false
            saveProfileError = "입력값을 다시 확인해주세요."
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            saveProfileError = "로그인 정보가 없습니다. 다시 로그인해주세요."
            return
        }

        guard let sex else {
            saveProfileError = "성별을 선택해주세요."
            return
        }

        let displayName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let friendCode = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let homeArea = fullAddressText

        isSavingProfile = true

        let db = Firestore.firestore()
        let doc = db.collection("Users").document(uid)

        let data: [String: Any] = [
            "displayName": displayName,
            "sex": sex.rawValue,
            "homeArea": homeArea,
            "createdAt": FieldValue.serverTimestamp(),
            "friendCode": friendCode
        ]

        doc.setData(data, merge: true) { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    self.saveProfileError = "저장에 실패했습니다: \(error.localizedDescription)"
                } else {
                    self.saveProfileError = nil
                    onSuccess?()
                }
                self.isSavingProfile = false
            }
        }
    }
}
