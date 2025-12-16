//
//  RunResultModalView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 5/31/25.
//

import FirebaseFirestore
import SwiftUI

struct RunResultModalView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject private var runRecordVM: RunRecordService
    @StateObject private var vm = RunResultModalViewModel()
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack(spacing: 20) {
                Text("이번엔 여기까지...")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 30))
                    .bold()
                    .padding(.top, 26)
                    .foregroundColor(.white)
                
                if let url = vm.routeImageURL {
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
                    if vm.capturedValue > 0 {
                        Text("\(vm.capturedValue)m²")
                            .font(.largeTitle02)
                            .foregroundColor(.white)
                            .padding(.top, -20)
                    }
                    
                    Spacer().frame(height: 0)
                    
                    if let duration = vm.duration,
                       let distance = vm.distance,
                       let calories = vm.calories
                    {
                        HStack(spacing: 40) {
                            VStack(spacing: 8) {
                                Text("시간")
                                Text(formatDuration(duration))
                            }
                            VStack(spacing: 8) {
                                Text("거리")
                                Text(String(format: "%.1f km", distance/1000))
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
                    if vm.hasRewardQueue {
                        vm.showRewardQueue = true
                    } else {
                        router.currentScreen = .main(id: UUID())
                    }
                }) {
                    Text(vm.hasReward ? "보상 확인하기" : "구역 확장 끝내기")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            vm.loadRecentRunRecord()
        }
        .overlay {
            if vm.showRewardQueue {
                RewardSequenceContainer(rewards: vm.rewardQueue, onComplete: {
                    vm.showRewardQueue = false
                    onComplete()
                })
                .environmentObject(router)
            }
        }
    }
}
