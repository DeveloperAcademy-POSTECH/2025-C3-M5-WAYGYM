//
//  Untitled.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/3/25.
//

import SwiftUI

struct DoubleRewardFlowView: View {
    let rewardImages: [String]  // 예: ["weapon_1", "minion_2"]
    let onComplete: () -> Void

    @State private var currentStep = 0

    var body: some View {
        if currentStep < rewardImages.count {
            NewRewardView(imageName: rewardImages[currentStep]) {
                withAnimation {
                    currentStep += 1
                }
            }
        } else {
            // 모든 보상 다 봤으면 완료 처리
            EmptyView()
                .onAppear {
                    onComplete()
                }
        }
    }
}
