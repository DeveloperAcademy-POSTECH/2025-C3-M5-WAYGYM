//
//  RunResultModalView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 5/31/25.
//

import FirebaseFirestore
import SwiftUI

struct RunResultModalView: View {
    @State private var hasReward: Bool = false

    @StateObject private var rewardService = RewardService()

    @ObservedObject var viewModel: MainViewModel
    let onComplete: () -> Void
    var onRewardSelected: ((WeaponDefinitionModel) -> Void)?

    @State private var rewardQueue: [RewardItem] = []
    @State private var showRewardQueue: Bool = false

    var body: some View {
        //        NavigationStack {
        ZStack {
            Color.clear
            
            VStack(spacing: 20) {
                Text("이번엔 여기까지...")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 30))
                    .bold()
                    .padding(.top, 26)
                // .padding(.bottom, -20)
                    .foregroundColor(.white)
                
                if let routeImage = viewModel.latestRunRecord?.routeImage,
                   let url = URL(string: routeImage) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 370)
                            .shadow(radius: 4)
                            .padding(.horizontal, -10)
                    } placeholder: {
                        ProgressView()
                            .frame(height: 370)
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 370)
                        .cornerRadius(12)
                        .overlay(Text("이미지 없음").foregroundColor(.gray))
                }
                
                VStack(spacing: 20) {
                    let capturedValue = viewModel.latestRunRecord?.capturedAreaValue ?? 0
                    if capturedValue > 0 {
                        Text("\(capturedValue)m²")
                            .font(.largeTitle02)
                            .foregroundColor(.white)
                            .padding(.top, -20)
                    }

                    Spacer().frame(height: 0)

                    if let record = viewModel.latestRunRecord {
                        let duration = record.duration
                        let distance = record.distance
                        let calories = duration / 60 * 7.4
                        HStack(spacing: 40) {
                            VStack(spacing: 8) {
                                Text("시간")
                                Text(formatDuration(duration))
                            }
                            VStack(spacing: 8) {
                                Text("거리")
                                Text(String(format: "%.1f km", distance / 1000))
                            }
                            VStack(spacing: 8) {
                                Text("칼로리")
                                Text("\(Int(calories))kcal")
                            }
                        }
                        .font(.title03)
                        .foregroundColor(.white)
                    }
                }
                
                Spacer().frame(height: 0)
                
                Button(action: {
                    if !rewardQueue.isEmpty {
                        showRewardQueue = true
                    } else {
                        onComplete()
                    }
                }) {
                    Text(hasReward ? "보상 확인하기" : "구역 확장 끝내기")
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .font(.custom("NeoDunggeunmoPro-Regular", size: 22))
                }
                .padding(.bottom)
            }
            .padding()
            .background(Color("ModalBackground"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.yellow.opacity(0.8), lineWidth: 2)
            )
            .frame(maxWidth: 340, maxHeight: 660)
            
        }
        .overlay {
            if showRewardQueue {
                RewardQueueView(rewards: rewardQueue, onComplete: {
                    showRewardQueue = false
                    onComplete()
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                viewModel.loadLatestRunResult()
                // 해금된 무기/똘마니 하나의 리워드 배열로 넣기
                var collectedRewards: [RewardItem] = []
                // 해금된 무기 찾기
                rewardService.checkWeaponUnlockOnStop { unlocked in
                    let weaponRewards = unlocked.map { RewardItem.weapon($0) }
                    collectedRewards.append(contentsOf: weaponRewards)
                    print("해금된 무기: \(unlocked.map {$0.id})")

                    // 해금된 똘마니 찾기
                    rewardService.checkMinionUnlockOnStop { unlockedMinions in
                        let minionRewards = unlockedMinions.map { RewardItem.minion($0)}
                        print("해금된 미니언: \(unlockedMinions.map {$0.id})")

                        // 해금된 똘마니/무기 배열에 넣을때, 미니언부터 앞으로 넣음
                        collectedRewards.insert(contentsOf: minionRewards, at: 0)

                        // 리워드가 있다면 배열로 저장하고, 버튼이 '보상 확인하기'로 바뀜
                        if !collectedRewards.isEmpty {
                            rewardQueue = collectedRewards
                            hasReward = true
                        }
                    }
                }
            }
    }
}

private func formatDuration(from start: Date, to end: Date) -> String {
    let interval = end.timeIntervalSince(start)
    let minutes = Int(interval / 60)
    return "\(minutes)분"
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: duration) ?? "00:00:00"
}

#Preview {
    RunResultModalView(
        viewModel: MainViewModel(),
        onComplete: {
            print("구역 확장 결과 모달 버튼 클릭")
        },
        onRewardSelected: { weapon in
            print("Reward selected: \(weapon.id)")
        }
    )
}
