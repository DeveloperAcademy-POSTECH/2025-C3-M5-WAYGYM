//
//  RewardQueueView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/9/25.
//

import SwiftUI

enum RewardItem {
    case minion(MinionDefinitionModel)
    case weapon(WeaponDefinitionModel)
}

struct RewardQueueView: View {
    let rewards: [RewardItem]
    @EnvironmentObject var router: AppRouter
    @State private var currentIndex: Int = 0
    let onComplete: () -> Void

    var body: some View {
        if currentIndex < rewards.count {
            return AnyView(
                Group {
                    switch rewards[currentIndex] {
                    case .minion(let minion):
                        MinionRewardView(minion: minion, onDismiss: {
                            currentIndex += 1
                        }, isLast: currentIndex == rewards.count - 1)
                    case .weapon(let weapon):
                        WeaponRewardView(weapon: weapon, onDismiss: {
                            currentIndex += 1
                        }, isLast: currentIndex == rewards.count - 1)
                    }
                }
            )
        } else {
            DispatchQueue.main.async {
                onComplete()
                router.currentScreen = .main
            }
            return AnyView(EmptyView())
        }
    }
}
