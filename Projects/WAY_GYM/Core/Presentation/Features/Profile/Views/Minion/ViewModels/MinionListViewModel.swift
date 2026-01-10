//
//  MinionListViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/1/25.
//

import Foundation

final class MinionListViewModel: ObservableObject {
    private let runRecordVM: RunRecordService
    private let minionService = MinionService()
    
    @Published var selectedMinion: MinionDefinitionModel? {
        didSet {
            guard let minion = selectedMinion else {
                acquisitionDate = nil
                return
            }
            minionService.acquisitionDateSmart(for: minion) { [weak self] date in
                DispatchQueue.main.async {
                    self?.acquisitionDate = date
                }
            }
        }
    }
    
    @Published private(set) var acquisitionDate: Date?
    @Published private(set) var acquiredMinions: [(minion: MinionDefinitionModel, acquisitionDate: Date)] = []
    
    init(runRecordVM: RunRecordService = RunRecordService()) {
        self.runRecordVM = runRecordVM
    }
    
    var acquisitionDateText: String {
        formatShortDate(acquisitionDate ?? Date())
    }
    
    // 런레코드 오퍼레이션의 콜백 함수
    // 고차 함수는 getTotalDistanceForRewards
    func fetchUnlockedMinions(_ total: Double) {
        let unlocked = MinionModel.allMinions.filter { minion in
            minionService.isUnlocked(minion, with: Int(total))
        }
        let sorted = unlocked.sorted { $0.unlockNumber < $1.unlockNumber }
        let items = sorted.map { (minion: $0, acquisitionDate: Date()) }
        
        DispatchQueue.main.async {
            self.acquiredMinions = items
        }
    }
    
    func isMinionUnlocked(_ minion: MinionDefinitionModel) -> Bool {
        return acquiredMinions.first(where: { $0.minion.id == minion.id }) != nil
    }
}
