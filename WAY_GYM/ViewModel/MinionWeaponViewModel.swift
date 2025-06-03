//
//  MinionSingleViewModel.swift
//  Ch3Personal
//
//  Created by 이주현 on 6/1/25.
//

import Foundation
import SwiftUI

final class MinionViewModel: ObservableObject {
    @Published var allMinions: [MinionDefinitionModel] = []
    @Published var runRecordVM: RunRecordViewModel

    init(runRecordVM: RunRecordViewModel) {
        self.runRecordVM = runRecordVM
    }

    func acquisitionDate(for minion: MinionDefinitionModel) -> Date? {
        let sorted = runRecordVM.runRecords.sorted { $0.startTime < $1.startTime }
        var cumulative: Double = 0

        for record in sorted {
            cumulative += record.distance
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
    
    @StateObject private var runRecordVM = RunRecordViewModel()

    func totalCaptureArea() -> Double {
        Double(runRecordVM.runRecords.map { $0.capturedAreaValue }.reduce(0, +))
    }

    func isUnlocked(_ weapon: WeaponDefinitionModel, with areaValue: Int) -> Bool {
        return Double(areaValue) >= weapon.unlockNumber
    }

    func toggleSelection(of weapon: WeaponDefinitionModel) {
        if selectedWeapon?.id == weapon.id {
            selectedWeapon = nil
        } else {
            selectedWeapon = weapon
        }
    }

    func acquisitionDate(for weapon: WeaponDefinitionModel, from records: [RunRecordModels]) -> Date? {
        let sorted = records.sorted { $0.startTime < $1.startTime }
        var cumulative: Double = 0

        for record in sorted {
            cumulative += Double(record.capturedAreaValue)
            if cumulative >= weapon.unlockNumber {
                return record.startTime
            }
        }
        return nil
    }
    
}
