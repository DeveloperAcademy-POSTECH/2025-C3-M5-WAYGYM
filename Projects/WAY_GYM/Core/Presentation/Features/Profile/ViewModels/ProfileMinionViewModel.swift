//
//  ProfileMinionViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/2/25.
//

import Foundation

final class ProfileMinionViewModel: ObservableObject {
    private let runRecordVM: RunRecordService
    private let minionService = MinionService()

    // 획득한 미니언
    @Published var recentMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []
    @Published var isLoading: Bool = true
    private var hasLoaded: Bool = false

    var recentMinionsWithIndex: [(minion: MinionDefinitionModel, acquisitionDate: Date, index: Int)] {
        recentMinions.compactMap { item in
            guard let index = MinionModel.allMinions.firstIndex(where: { $0.id == item.minion.id }) else {
                return nil
            }
            return (minion: item.minion, acquisitionDate: item.acquisitionDate, index: index)
        }
    }

    init(runRecordVM: RunRecordService) {
        self.runRecordVM = runRecordVM
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        fetchRecentUnlockedMinions()
    }

    private func fetchRecentUnlockedMinions() {
        minionService.fetchRecentUnlockedMinions(runRecordVM: runRecordVM) { [weak self] recent in
            DispatchQueue.main.async {
                // 정책: 최근 3개만 노출 (필요 시 조정 가능)
                self?.recentMinions = Array(recent.suffix(3))
                self?.isLoading = false
            }
        }
    }

}
