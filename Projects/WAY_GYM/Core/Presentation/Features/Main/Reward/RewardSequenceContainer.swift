//
//  RewardQueueView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/9/25.
//

import SwiftUI

enum RewardType {
    case weapon(WeaponDefinitionModel)
    case minion(MinionDefinitionModel)
}

struct RewardSequenceContainer: View {
    let rewards: [RewardType]
    @EnvironmentObject var router: AppRouter
    @State private var currentIndex: Int = 0
    let onComplete: () -> Void

    var body: some View {
        if currentIndex < rewards.count {
            return AnyView(
                Group {
                    switch rewards[currentIndex] {
                    case .minion(let minion):
                        RewardItemView(
                            type: .minion(minion),
                            isLast: currentIndex == rewards.count - 1,
                            onDismiss: { currentIndex += 1 }
                        )
                    case .weapon(let weapon):
                        RewardItemView(
                            type: .weapon(weapon),
                            isLast: currentIndex == rewards.count - 1,
                            onDismiss: { currentIndex += 1 }
                        )
                    }
                }
            )
        } else {
            DispatchQueue.main.async {
                onComplete()
                router.currentScreen = .main(id: UUID())
            }
            return AnyView(EmptyView())
        }
    }
}
