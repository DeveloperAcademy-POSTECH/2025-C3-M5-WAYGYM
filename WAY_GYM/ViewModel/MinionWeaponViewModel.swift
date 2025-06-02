//
//  MinionSingleViewModel.swift
//  Ch3Personal
//
//  Created by 이주현 on 6/1/25.
//

import Foundation

final class MinionViewModel: ObservableObject {
    @Published var allMinions: [MinionDefinitionModel] = []
    @Published var ownedMinionIDs: Set<String> = []

    func acquisitionDate(for minion: MinionDefinitionModel, in runs: [RunRecordModel]) -> Date? {
        let sorted = runs.sorted { $0.startTime < $1.startTime }
        var cumulative: Double = 0

        for record in sorted {
            cumulative += record.totalDistance
            if cumulative >= minion.unlockNumber * 1000 {
                return record.startTime
            }
        }
        return nil
    }
}

final class WeaponViewModel: ObservableObject {
    @Published var allWeapons: [WeaponDefinitionModel] = []
    @Published var selectedWeapon: WeaponDefinitionModel? = nil
    
    func totalCaptureArea(from runs: [RunRecordModel]) -> Double {
        runs.map { $0.capturedAreaValue }.reduce(0, +)
    }

    func isWeaponUnlocked(_ weapon: WeaponDefinitionModel, for runs: [RunRecordModel]) -> Bool {
        totalCaptureArea(from: runs) >= weapon.unlockNumber * 1_000_000
    }

    func toggleSelection(of weapon: WeaponDefinitionModel) {
        if selectedWeapon?.id == weapon.id {
            selectedWeapon = nil
        } else {
            selectedWeapon = weapon
        }
    }
}
