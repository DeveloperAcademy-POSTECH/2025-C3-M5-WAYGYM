//
//  RewardService.swift
//
//  Created by 이주현 on 6/1/25.
//

import Foundation
import SwiftUI

final class RewardService: ObservableObject {
    @Published var allMinions: [MinionDefinitionModel] = []
    @Published var selectedMinion: MinionDefinitionModel? = nil
    @Published var currentRewardMinion: MinionDefinitionModel? = nil
    @StateObject private var runRecordVM = RunRecordStore()
    private let runRecordModelsRepository: RunRecordModelsRepositoryProtocol
    
    // MARK: - 미니언: 점령전(듀오) 승리 보상
    private var minionModel = MinionModel()
    init(runRecordModelsRepository: RunRecordModelsRepositoryProtocol = RunRecordModelsRepository()) {
        self.runRecordModelsRepository = runRecordModelsRepository
        self.allMinions = minionModel.allMinions
    }
    
    func isUnlocked(_ minion: MinionDefinitionModel, with distanceValue: Int) -> Bool {
        return Double(distanceValue) >= minion.unlockNumber * 1000
    }

    // 무기 얻은 날짜 계산 함수
    func acquisitionDate(for minion: MinionDefinitionModel) -> Date? {
        let sorted = runRecordVM.runRecords.sorted { $0.startTime < $1.startTime }
        var cumulative: Double = 0

        for record in sorted {
            cumulative += record.distanceM
            if cumulative >= minion.unlockNumber * 1000 {
                return record.startTime
            }
        }
        return nil
    }
    
    // 새로 획득한 미니언 확인 함수
    func checkMinionUnlockOnStop(completion: @escaping ([MinionDefinitionModel]) -> Void) {
        Task {
            do {
                let records = try await runRecordModelsRepository.fetchAllRunRecordSummaries()
                let sorted = records.sorted { $0.startTime > $1.startTime }

                guard let latestRecord = sorted.first else {
                    print("⚠️ 기록 없음")
                    await MainActor.run { completion([]) }
                    return
                }

                let currentTotal = records.map { $0.distance }.reduce(0, +)
                let prevTotal = currentTotal - latestRecord.distance

                print("거리 📏 총: \(currentTotal), 총-최신 기록: \(prevTotal)")

                var newlyUnlockedMinions: [MinionDefinitionModel] = []

                for minion in self.allMinions {
                    let unlock = minion.unlockNumber * 1000

                    let wasLockedBefore = prevTotal < unlock
                    let isUnlockedNow = currentTotal >= unlock

                    if wasLockedBefore && isUnlockedNow {
                        newlyUnlockedMinions.append(minion)
                    }
                }

                await MainActor.run {
                    completion(newlyUnlockedMinions)
                }
            } catch {
                print("⚠️ 기록 불러오기 실패: \(error.localizedDescription)")
                await MainActor.run { completion([]) }
            }
        }
    }
}
