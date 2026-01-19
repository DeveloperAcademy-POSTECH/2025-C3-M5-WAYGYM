//
//  RewardQueueView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/9/25.
//

import SwiftUI

struct RewardQueueView: View {
    let weapons: [WeaponDefinitionModel]
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var currentIndex: Int = 0
    let onComplete: () -> Void

    var body: some View {
        Group {
            if currentIndex < weapons.count {
                let weapon = weapons[currentIndex]
                WeaponRewardView(
                    weapon: weapon,
                    onDismiss: {
                        currentIndex += 1
                    },
                    isLast: currentIndex == weapons.count - 1
                )
            } else {
                Color.clear
                    .onAppear {
                        onComplete()
                        coordinator.popToRoot()
                    }
            }
        }
    }
}
