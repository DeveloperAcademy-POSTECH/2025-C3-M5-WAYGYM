//
//  WeaponListViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/19/25.
//

import Foundation

@MainActor
final class WeaponListViewModel: ObservableObject {
    @Published var selectedWeaponId: String {
        didSet { UserDefaults.standard.set(selectedWeaponId, forKey: "selectedWeaponId") }
    }

    @Published var acquisitionDate: Date?
    @Published private(set) var totalCapturedAreaValue: Int = 0

    private var cachedRuns: [RunCardModel] = []

    private let weaponModel = WeaponModel()

    init() {
        self.selectedWeaponId = UserDefaults.standard.string(forKey: "selectedWeaponId") ?? "0"
    }

    var allWeapons: [WeaponDefinitionModel] { weaponModel.allWeapons }

    // 현재 장착된 무기
    var selectedWeapon: WeaponDefinitionModel? {
        allWeapons.first { $0.id == selectedWeaponId }
    }
    
    // 해당 무기가 장착 상태인지 여부
    func isSelected(_ weapon: WeaponDefinitionModel) -> Bool {
        return selectedWeaponId == weapon.id
    }

    // 화면에 보여줄 무기
    var selectedDisplayWeapon: WeaponDefinitionModel? {
        guard let weapon = selectedWeapon, weapon.id != "0" else { return nil }
        return weapon
    }

    func onAppear() {
        Task {
            do {
                let all = try await RunCardModel.fetchRunSummary()
                await MainActor.run {
                    self.cachedRuns = all
                    let sum = all.reduce(0) { $0 + Int($1.capturedArea) }
                    self.totalCapturedAreaValue = sum
                    self.refreshAcquisitionDate()
                }
            } catch {
                print("⚠️ Failed to load total captured area: \(error.localizedDescription)")
            }
        }
    }

    func isUnlocked(_ weapon: WeaponDefinitionModel) -> Bool {
        return Double(totalCapturedAreaValue) >= weapon.unlockNumber
    }

    func toggleSelection(_ weapon: WeaponDefinitionModel) {
        if selectedWeaponId == weapon.id {
            selectedWeaponId = "0"
        } else {
            selectedWeaponId = weapon.id
        }
        refreshAcquisitionDate()
    }

    func refreshAcquisitionDate() {
        guard let weapon = selectedWeapon, weapon.id != "0" else {
            self.acquisitionDate = nil
            return
        }
        
        guard !cachedRuns.isEmpty else {
            self.acquisitionDate = nil
            return
        }
        let sorted = cachedRuns.sorted { $0.startTime < $1.startTime }
        var cumulative: Double = 0
        for run in sorted {
            cumulative += run.capturedArea
            if cumulative >= weapon.unlockNumber {
                self.acquisitionDate = run.startTime
                return
            }
        }
        self.acquisitionDate = nil
    }
}
