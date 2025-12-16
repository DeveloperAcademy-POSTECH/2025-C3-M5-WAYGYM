//
//  SettingViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/28/25.
//

import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

final class SettingViewModel: ObservableObject {
    @Published var localUser: LocalUser? = LocalUserStore.load()
    @Published var locationVM = AddressPickerViewModel()
    
    @Published var isEditingProfile: Bool = false
    @Published var editName: String = ""
    @Published var editGender: String = ""
    @Published var editBirthDate: Date = Date()   // displayedComponents: .date
    @Published var editHeight: String = ""  // cm
    @Published var editWeight: String = ""  // kg
    @Published var editRegion: String = ""
    
    @Published var regionSource: RegionSource = .none
    @Published var showCitySheet: Bool = false
    @Published var showTownSheet: Bool = false
    
    func onAppear() {
        self.localUser = LocalUserStore.load()
    }
    
    var phoneNumberText: String {
        Auth.auth().currentUser?.phoneNumber ?? "불러올 수 없습니다."
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
            print("로그아웃 성공")
        } catch let signOutError as NSError {
            print("로그아웃 에러: %@", signOutError)
        }
    }
    
    func pushLocalToServerAndCache(_ local: LocalUser) {
        let db = Firestore.firestore()
        let user = UserModel(
            id: local.id,
            name: local.name,
            birthDate: local.birthDate,
            height: local.height,
            weight: local.weight,
            gender: local.gender,
            region: local.region
        )
        do {
            try db.collection("Users").document(local.id).setData(from: user) { error in
                if let error = error {
                    print("❌ Update user failed: \(error.localizedDescription)")
                    return
                }
                db.collection("Users").document(local.id).getDocument { snapshot, fetchError in
                    if let fetchError = fetchError {
                        print("❌ Fetch after update failed: \(fetchError.localizedDescription)")
                        return
                    }
                    guard let snapshot = snapshot, snapshot.exists else {
                        print("❌ No snapshot after update")
                        return
                    }
                    do {
                        let latest = try snapshot.data(as: UserModel.self)
                        LocalUserStore.save(latest)
                        DispatchQueue.main.async {
                            self.localUser = LocalUserStore.load()
                        }
                        print("✅ Local cache refreshed")
                    } catch {
                        print("❌ Decode after update: \(error)")
                    }
                }
            }
        } catch {
            print("❌ Encoding error: \(error)")
        }
    }
    
    func startEditing() {
        guard let u = localUser else { return }
        editName = u.name
        editGender = u.gender
        editBirthDate = u.birthDate
        editHeight = u.height == 0 ? "" : String(Int(u.height))
        editWeight = u.weight == 0 ? "" : String(Int(u.weight))
        editRegion = u.region
        prefillRegionPickers(from: editRegion)
        isEditingProfile = true
    }
    
    func cancelEditing() {
        isEditingProfile = false
    }
    
    func saveEdits() {
        guard var u = localUser else { isEditingProfile = false; return }
        // Keep only Y-M-D (strip time)
        let cal = Calendar.current
        let ymd = cal.dateComponents([.year, .month, .day], from: editBirthDate)
        let only = cal.date(from: ymd) ?? editBirthDate
        
        let newHeight = Double(editHeight) ?? 0
        let newWeight = Double(editWeight) ?? 0
        
        // Build updated LocalUser
        u = LocalUser(id: u.id,
                      name: editName.trimmingCharacters(in: .whitespacesAndNewlines),
                      birthDate: only,
                      height: newHeight,
                      weight: newWeight,
                      gender: editGender.trimmingCharacters(in: .whitespacesAndNewlines),
                      region: editRegion.trimmingCharacters(in: .whitespacesAndNewlines))
        // Push to server and refresh local cache/state
        pushLocalToServerAndCache(u)
        isEditingProfile = false
    }

    func prefillRegionPickers(from editRegion: String) {
        // 0) 방어 코드 & 데이터 준비
        let trimmed = editRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        
        // 데이터 준비 (필요 시 로드)
        if locationVM.provinces.isEmpty {
            locationVM.load()
        }
        
        // 토큰화
        let tokens = trimmed.split(separator: " ").map(String.init)
        guard let firstToken = tokens.first, let lastToken = tokens.last else {
            return
        }
        
        // 1) 두번째 Picker(시/군/구) = 첫 단어(firstToken)를 '포함'하는 city를 찾는다
        var matchedProvinceIndex: Int? = nil
        var matchedCityIndex: Int? = nil
        
        outer: for (pIdx, province) in locationVM.provinces.enumerated() {
            for (cIdx, city) in province.cities.enumerated() {
                if city.name.contains(firstToken) {
                    matchedProvinceIndex = pIdx
                    matchedCityIndex = cIdx
                    break outer
                }
            }
        }
        
        guard let pIdx = matchedProvinceIndex, let cIdx = matchedCityIndex else {
            return
        }
        
        // 2) 첫번째 Picker(시/도) & 2단계 적용
        locationVM.selectedProvinceIndex = pIdx
        locationVM.selectedCityIndex = cIdx
        
        // 3) 세번째 Picker(읍/면/동/리) = 마지막 단어(lastToken) 기준으로 '정확 일치' 우선, 실패 시 '포함'으로 보정
        let towns = locationVM.provinces[pIdx].cities[cIdx].towns
        
        if let exactIdx = towns.firstIndex(where: { $0 == lastToken }) {
            locationVM.selectedTownIndex = exactIdx
        } else if let containsIdx = towns.firstIndex(where: { $0.contains(lastToken) }) {
            locationVM.selectedTownIndex = containsIdx
        }
    }
    
}
