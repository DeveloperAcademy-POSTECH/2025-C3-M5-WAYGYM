//
//  MinionSingleViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/1/25.
//

import Foundation

final class MinionSingleViewModel: ObservableObject {
    // MARK: - Input
    let minionIndex: Int

    // MARK: - Model Dependency (direct)
    private let minionService = MinionService()

    // MARK: - UI State
    @Published var acquisitionDate: Date? = nil
    @Published var allMinions: [MinionDefinitionModel] = MinionModel.allMinions
    @Published var acquiredMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []

    // MARK: - Derived
    var minion: MinionDefinitionModel { MinionModel.allMinions[minionIndex] }

    // MARK: - Init
    init(minionIndex: Int) {
        self.minionIndex = minionIndex
        self.allMinions = MinionModel.allMinions
    }
}

// MARK: - Public API (merged from MinionOperation)
extension MinionSingleViewModel {
//    func isUnlocked(_ minion: MinionDefinitionModel, with distanceValue: Int) -> Bool {
//        minionService.isUnlocked(minion, with: distanceValue)
//    }

    func acquisitionDateSmart(for minion: MinionDefinitionModel, completion: @escaping (Date?) -> Void) {
        minionService.acquisitionDateSmart(for: minion, completion: completion)
    }

    func checkMinionUnlockOnStop(completion: @escaping ([MinionDefinitionModel]) -> Void) {
        minionService.checkMinionUnlockOnStop(completion: completion)
    }

    func fetchRecentUnlockedMinions(runRecordVM: RunRecordService,
                                    completion: @escaping ([(minion: MinionDefinitionModel, acquisitionDate: Date)]) -> Void) {
        minionService.fetchRecentUnlockedMinions(runRecordVM: runRecordVM, completion: completion)
    }

    func fetchRecentUnlockedMinions() {
        minionService.fetchRecentUnlockedMinions()
        DispatchQueue.main.async { [weak self] in
            self?.acquiredMinions = self?.minionService.acquiredMinions ?? []
        }
    }
}

// MARK: - Screen lifecycle helpers
extension MinionSingleViewModel {
    func load() {
        acquisitionDateSmart(for: minion) { [weak self] date in
            DispatchQueue.main.async {
                self?.acquisitionDate = date
            }
        }
    }
}
