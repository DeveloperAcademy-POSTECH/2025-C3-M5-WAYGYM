//
//  SettingProfileViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 2/6/25.
//

import Foundation
import FirebaseAuth

final class ProfileEditViewModel: ObservableObject {
    private let userRepository: UserRepositoryProtocol = UserRepository()

    @Published var sex: ProfileSetupViewModel.Sex? = nil
    @Published var nickname: String = ""
    @Published var userId: String = ""

    @Published var sido: String = ""
    @Published var sigungu: String = ""
    @Published var dong: String = ""
    let addressData: [SidoNode]
    private let locationService = LocationAddressService()
    enum AddressMode: String, CaseIterable { case current = "현위치", manual = "직접 선택" }
    @Published var addressMode: AddressMode = .manual
    @Published var isAddressPickerPresented: Bool = false

    @Published var nicknameError: String? = nil
    @Published var sexError: String? = nil
    @Published var addressError: String? = nil

    @Published var isSavingProfile: Bool = false
    @Published var saveProfileError: String? = nil

    private var hasLoadedProfile: Bool = false
    private var originalFriendCode: String? = nil

    // Change detection (no extra model)
    private var originalNickname: String = ""
    private var originalSexRaw: String? = nil
    private var originalHomeArea: String = ""
    private var originalUserId: String = ""

    init() {
        self.addressData = (try? AddressLoader.load3DepthJSON()) ?? []
    }

    var fullAddressText: String {
        [sido, sigungu, dong].filter { !$0.isEmpty }.joined(separator: " ")
    }

    func loadProfileIfNeeded(_ profile: User?) {
        guard !hasLoadedProfile, let profile else { return }
        hasLoadedProfile = true

        nickname = profile.displayName ?? ""
        originalFriendCode = profile.friendCode
        userId = profile.friendCode ?? ""

        if let sexRaw = profile.sex, let savedSex = ProfileSetupViewModel.Sex(rawValue: sexRaw) {
            sex = savedSex
        }

        if let homeArea = profile.homeArea, !homeArea.isEmpty {
            applyHomeArea(homeArea)
            addressMode = .manual
        }

        // Capture originals for change detection (after we applied loaded values)
        originalNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        originalSexRaw = sex?.rawValue
        originalHomeArea = fullAddressText
        originalUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyHomeArea(_ homeArea: String) {
        let parts = homeArea.split(separator: " ").map(String.init)
        if parts.indices.contains(0) { sido = parts[0] }
        if parts.indices.contains(1) { sigungu = parts[1] }
        if parts.count >= 3 { dong = parts[2...].joined(separator: " ") }
    }
}

// MARK: - Rules
extension ProfileEditViewModel {
    var hasChanges: Bool {
        guard hasLoadedProfile else { return false }

        let currentNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentSexRaw = sex?.rawValue
        let currentHomeArea = fullAddressText
        let currentUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)

        // Note: userId is currently not editable in the view, but included for future-proofing.
        return currentNickname != originalNickname ||
               currentSexRaw != originalSexRaw ||
               currentHomeArea != originalHomeArea ||
               currentUserId != originalUserId
    }
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

    func validateAddress() {
        if fullAddressText.isEmpty {
            addressError = "주소를 설정해주세요."
        } else {
            addressError = nil
        }
    }

    var canSave: Bool {
        hasChanges && [
            nicknameError == nil,
            addressError == nil,
            sexError == nil,
            !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !fullAddressText.isEmpty,
            sex != nil
        ].allSatisfy { $0 }
    }
}

// MARK: - Actions
extension ProfileEditViewModel {
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

    func saveProfileToFirestore(onSuccess: (() -> Void)? = nil) {
        guard !isSavingProfile else { return }

        saveProfileError = nil

        validateNickname()
        validateSex()
        validateAddress()

        guard canSave else {
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
        let homeArea = fullAddressText
        let friendCode = (originalFriendCode ?? userId).trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingProfile = true

        let profile = User(
            displayName: displayName,
            homeArea: homeArea,
            sex: sex.rawValue,
            friendCode: friendCode.isEmpty ? nil : friendCode,
            createdAt: nil
        )
        Task {
            do {
                try await userRepository.saveProfile(uid: uid, profile: profile)
                await MainActor.run {
                    self.saveProfileError = nil
                    self.isSavingProfile = false
                    onSuccess?()
                }
            } catch {
                await MainActor.run {
                    self.saveProfileError = "저장에 실패했습니다: \(error.localizedDescription)"
                    self.isSavingProfile = false
                }
            }
        }
    }
}
