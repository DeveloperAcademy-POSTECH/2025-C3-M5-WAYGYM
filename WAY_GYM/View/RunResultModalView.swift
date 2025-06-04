//
//  RunResultModalView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 5/31/25.
//

import SwiftUI
import FirebaseFirestore

struct RunResultModalView: View {
    // let capture: RunRecordModels
    @State private var latestRecord: RunRecordModels? // 서버에서 제일 최신 기록 가져오기
    
    // let onComplete: () -> Void
    // let hasReward: Bool // 보상 유무
    @State private var hasReward: Bool = false

    @StateObject private var weaponVM = WeaponViewModel()
    
    @EnvironmentObject var router: AppRouter

    var body: some View {
        NavigationStack {
            ZStack{
                Color.black.opacity(0.7)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("이번엔 여기까지...")
                        .font(.custom("NeoDunggeunmoPro-Regular", size: 30))
                        .bold()
                        .padding(.top, 26)
                        .padding(.bottom, -20)
                        .foregroundColor(.white)

                    if let record = latestRecord {
                        if let imageName = record.routeImage {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 370)
                                .shadow(radius: 4)
                                .padding(.horizontal, -10)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 370)
                                .cornerRadius(12)
                                .overlay(Text("이미지 없음").foregroundColor(.gray))
                        }

                        Text("\(String(format: "%.1f", record.capturedAreaValue))m²")
                            .font(.largeTitle02)
                            .foregroundColor(.white)
                            .padding(.top, -20)

                        Spacer().frame(height: 0)

                        HStack(spacing: 50){
                            VStack(spacing: 8) {
                                Text("시간")
                                Text(formatDuration(from: record.startTime, to: record.endTime ?? Date()))
                            }
                            VStack(spacing: 8) {
                                Text("거리")
                                Text(String(format: "%.1f km", record.distance / 1000))
                            }
                            VStack(spacing: 8) {
                                Text("칼로리")
                                Text("\(Int(record.caloriesBurned))kcal")
                            }
                        }
                        .font(.title03)
                        .foregroundColor(.white)
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
        }
        
        .onAppear {
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

            let db = Firestore.firestore()
            db.collection("RunRecordModels")
                .order(by: "startTime", descending: true)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    guard let document = snapshot?.documents.first else { return }
                    let data = document.data()

                    // 필드별 안전한 추출
                    let routeImage = data["routeImage"] as? String
                    let capturedAreaValue = data["capturedAreaValue"] as? Double ?? 0.0
                    let startTimestamp = data["start_time"] as? Timestamp
                    let endTimestamp = data["end_time"] as? Timestamp
                    let caloriesBurned = data["calories_burned"] as? Double ?? 0.0
                    let distance = data["distance"] as? Double ?? 0.0

                    DispatchQueue.main.async {
                        latestRecord = RunRecordModels(
                            id: document.documentID,
                            distance: distance,
                            stepCount: 0,
                            caloriesBurned: caloriesBurned,
                            startTime: startTimestamp?.dateValue() ?? Date(),
                            endTime: endTimestamp?.dateValue() ?? Date(),
                            routeImage: routeImage,
                            coordinates: [],
                            capturedAreas: [],
                            capturedAreaValue: Int(capturedAreaValue)
                        )
                    }
                }
            
        }
    }

//    private func formatDuration(_ duration: TimeInterval) -> String{
//                let formatter = DateComponentsFormatter()
//                formatter.allowedUnits = [.hour, .minute, .second]
//                formatter.unitsStyle = .positional
//                formatter.zeroFormattingBehavior = .pad
//                return formatter.string(from: duration) ?? "00:00:00"
//    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let minutes = Int(interval / 60)
        return "\(minutes)분"
    }
}
