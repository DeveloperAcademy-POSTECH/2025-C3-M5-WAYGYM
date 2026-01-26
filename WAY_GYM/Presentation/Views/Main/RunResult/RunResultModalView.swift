//
//  RunResultModalView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 5/31/25.
//

import FirebaseFirestore
import SwiftUI

struct RunResultModalView: View {
    @ObservedObject var viewModel: MainViewModel
    let onComplete: () -> Void
    
    @State private var rewardQueue: [WeaponDefinitionModel] = []
    @State private var showRewardQueue: Bool = false
    private var hasReward: Bool {
        !rewardQueue.isEmpty
    }

    private let weaponModel = WeaponModel()

    var body: some View {
        ZStack {
            Color.clear
            
            VStack(spacing: 24) {
                Text("이번엔 여기까지...")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 30))
                    .bold()
                    .padding(.top, 26)
                    .foregroundColor(.white)

                MiniMapThumbnail(
                    route: PolylineDecoder.decode(routeEncoded: viewModel.latestRunRecord?.routeEncoded ?? ""),
                    polygons: [],
                    showsBackground: false
                )
                .frame(width: 222, height: 288)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                    // TODO: 임시 계산: 셀 1칸 = 100m²
                    let capturedValue = (viewModel.latestRunRecord?.capturedCellIds.count ?? 0) * 100
                    if capturedValue > 0 {
                        Text("\(capturedValue)m²")
                            .font(.largeTitle02)
                            .foregroundColor(.white)
                            .padding(.top, -20)
                    }
                
                    if let record = viewModel.latestRunRecord {
                        let duration = record.duration
                        let distance = record.distanceM
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
                RewardQueueView(weapons: rewardQueue, onComplete: {
                    viewModel.clearJustUnlockedWeapons()
                    showRewardQueue = false
                    onComplete()
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // fetch 완료 전에 이전 큐가 남아있지 않게 비움
            rewardQueue = []
            viewModel.loadLatestRunResult()
        }
        .onChange(of: viewModel.justUnlockedWeaponIds) { _, newIds in
            rewardQueue = newIds.compactMap { id in
                weaponModel.allWeapons.first(where: { $0.id == id })
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

#Preview("RunResultModalView – Dummy Data") {
    let vm = MainViewModel()

    // 📌 더미 런 기록 (최근 런 결과)
    vm.latestRunRecord = RunRecord(
        id: "dummy-run-id",
        startTime: Date().addingTimeInterval(-30 * 60), // 30분 전
        endTime: Date(),
        distanceM: 3200, // 3.2km
        routeEncoded: "ixb{E{nttWoEMiE]cE@yDOdEF}DG`EAwEEvEFyEItE\\{DStDB_E?dE@aEW`Ef@sEg@`ELoDF|DA{D@rDJcEOpE?uEIdEZiEc@|EP{ECjEVqDk@",
        capturedCellIds: Array(repeating: "36.064163,129.379981", count: 12),
        routeFrame: [36.0635, 129.3790, 36.0650, 129.3810]
    )

    return RunResultModalView(
        viewModel: vm,
        onComplete: {
            print("Preview complete tapped")
        }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
