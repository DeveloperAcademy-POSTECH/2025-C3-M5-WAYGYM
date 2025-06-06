//
//  RunResultModalView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 5/31/25.
//

import FirebaseFirestore
import SwiftUI

struct RunResultModalView: View {
    @State private var latestRecord: RunRecordModels?  // 서버에서 제일 최신 기록 가져오기

    @State private var hasReward: Bool = false

    @StateObject private var weaponVM = WeaponViewModel()

    @EnvironmentObject var router: AppRouter

    let onComplete: () -> Void
    // let hasReward: Bool  // 보상 유무
    @EnvironmentObject private var runRecordVM: RunRecordViewModel
    @State private var currentRecord: RunRecordModels?

    @State private var routeImageURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("이번엔 여기까지...")
                        .font(.custom("NeoDunggeunmoPro-Regular", size: 30))
                        .bold()
                        .padding(.top, 26)
                        .padding(.bottom, -20)
                        .foregroundColor(.white)

                    if let url = routeImageURL {
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
                        let capturedValue = runRecordVM.totalCapturedAreaValue
                        if capturedValue > 0 {
                            Text("\(capturedValue)m²")
                                .font(.largeTitle02)
                                .foregroundColor(.white)
                                .padding(.top, -20)
                        }

                        Spacer().frame(height: 0)

                        if let duration = runRecordVM.duration,
                            let distance = runRecordVM.distance,
                            let calories = runRecordVM.calories
                        {

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
                        if hasReward, let selected = weaponVM.currentRewardWeapon {
                            router.currentScreen = .weaponReward(selected)
                        } else {
                            router.currentScreen = .main
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
            
            
            .onAppear {
                runRecordVM.fetchLatestRouteImageOnly { urlString in
                    if let urlString = urlString,
                        let url = URL(string: urlString)
                    {
                        self.routeImageURL = url
                    }
                }

                runRecordVM.fetchLatestDistanceDurationCalories { _, _, _ in
                    print("✅ 거리, 시간, 칼로리 최신값 로드 완료")
                }

                runRecordVM.fetchLatestCapturedAreaValue { value in
                    if let value = value {
                        runRecordVM.totalCapturedAreaValue = Int(value)
                    }
                }

                runRecordVM.fetchRunRecordsFromFirestore()

                weaponVM.checkWeaponUnlockOnStop { unlocked in
                    // .last: 일단 해금된 무기가 여러 개 있더라도 마지막 것만 받아옴
                    if let unlockedWeapon = unlocked.last {
                        DispatchQueue.main.async {
                            weaponVM.currentRewardWeapon = unlockedWeapon
                            hasReward = true
                        }
                    }
                    print("🔓 해금된 무기: \(unlocked.map { $0.id })")
                }
              
            }
            .onChange(of: runRecordVM.runRecords) { records in
                print("🔥 데이터 로드됨: \(records.count)개")
                // 데이터가 로드되면 가장 최근 기록을 현재 기록으로 설정

                if let latestRecord = records.first {
                    currentRecord = latestRecord
                    print("✅ currentRecord 설정됨: \(latestRecord)")
                } else {
                    print("❌ 기록이 없음")
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
        onComplete: {
            print("구역 확장 결과 모달 버튼 클릭")
        }
        //hasReward: true
    )
    .environmentObject(RunRecordViewModel())
}
