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

protocol UserIdAvailabilityChecking {
    /// true면 사용 가능(중복 아님)
    func isAvailable(userId: String) async throws -> Bool
}

// Mock (나중에 API로 교체)
struct MockUserIdChecker: UserIdAvailabilityChecking {
    func isAvailable(userId: String) async throws -> Bool {
        try await Task.sleep(nanoseconds: 500_000_000)
        let blocked = ["admin", "root", "test", "judy", "gang"]
        return !blocked.contains(userId.lowercased())
    }
}

@MainActor
final class ProfileSetupViewModel: ObservableObject {
    // Input
    @Published var nickname: String = ""
    @Published var userId: String = ""

    // Address
    @Published var sido: String = ""
    @Published var sigungu: String = ""
    @Published var dong: String = ""

    enum AddressMode: String, CaseIterable { case current = "현위치", manual = "직접 선택" }
    @Published var addressMode: AddressMode = .current
    @Published var isAddressPickerPresented: Bool = false

    // Validation states
    @Published var nicknameError: String? = nil
    @Published var userIdError: String? = nil
    @Published var addressError: String? = nil

    @Published var isCheckingUserId: Bool = false
    @Published var userIdChecked: Bool = false
    @Published var userIdAvailable: Bool = false
    
    @Published var isSavingProfile: Bool = false
    @Published var saveProfileError: String? = nil

    // Data
    let addressData: [SidoNode]

    private let checker: UserIdAvailabilityChecking
    private let locationService = LocationAddressService()

    init(checker: UserIdAvailabilityChecking = MockUserIdChecker()) {
        self.checker = checker
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

    func validateUserId() {
        userIdChecked = false
        userIdAvailable = false

        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty { userIdError = "아이디를 입력해주세요."; return }
        if trimmed.count < 3 || trimmed.count > 20 { userIdError = "3~20자 범위로 입력해주세요."; return }

        // Instagram-ish: letters/digits/._- (특수문자 범위를 늘리고 싶으면 여기 수정)
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
            !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !fullAddressText.isEmpty,
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
                sido = addr.sido
                sigungu = addr.sigungu
                dong = addr.dong
                validateAddress()
            } catch {
                addressError = "현위치 주소를 불러오지 못했습니다. 직접 선택으로 설정해주세요."
            }
        }
    }

    func tapCheckUserId() {
        validateUserId()
        guard userIdError == nil else { return }

        let candidate = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        isCheckingUserId = true
        userIdChecked = false
        userIdAvailable = false

        Task {
            do {
                let available = try await checker.isAvailable(userId: candidate)
                userIdAvailable = available
                userIdChecked = true
                userIdError = available ? nil : "이미 사용 중인 아이디입니다."
            } catch {
                userIdChecked = false
                userIdAvailable = false
                userIdError = "중복 확인에 실패했습니다. 다시 시도해주세요."
            }
            isCheckingUserId = false
        }
    }
    
    func saveProfileToFirestore() {
        saveProfileError = nil

        guard canSubmit else {
            saveProfileError = "입력값을 다시 확인해주세요."
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            saveProfileError = "로그인 정보가 없습니다. 다시 로그인해주세요."
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
            "homeArea": homeArea,
            "createdAt": FieldValue.serverTimestamp(),
            "friendCode": friendCode
        ]

        doc.setData(data, merge: true) { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.saveProfileError = "저장에 실패했습니다: \(error.localizedDescription)"
                } else {
                    self.saveProfileError = nil
                }
                self.isSavingProfile = false
            }
        }
    }
}
