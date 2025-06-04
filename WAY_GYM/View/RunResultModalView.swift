//
//  RunResultModalView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 5/31/25.
//

import SwiftUI

struct RunResultModalView: View {
    let onComplete: () -> Void
    let hasReward: Bool  // 보상 유무
    // @StateObject private var runRecordVM = RunRecordViewModel()
    @EnvironmentObject private var runRecordVM: RunRecordViewModel
    @State private var currentRecord: RunRecordModels?
    
    @State private var routeImageURL: URL?

    var body: some View {
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

                //                Text("기록 개수: \(runRecordVM.totalCapturedAreaValue)")
                //                    .foregroundColor(.white)

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

                if let record = currentRecord {
                    Text(
                        "\(String(format: "%.1f", record.capturedAreaValue))m²"
                    )
                    .font(.largeTitle02)
                    .foregroundColor(.white)
                    .padding(.top, -20)

                    Spacer().frame(height: 0)

                    HStack(spacing: 50) {
                        VStack(spacing: 8) {
                            Text("시간")
                            Text(formatDuration(record.duration))
                        }
                        VStack(spacing: 8) {
                            Text("거리")
                            Text(
                                String(
                                    format: "%.1f km",
                                    record.distance / 1000
                                )
                            )
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
                if hasReward {
                    Button(action: {
                        onComplete()
                    }) {
                        Text("보상 확인하기")
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.yellow)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .font(.custom("NeoDunggeunmoPro-Regular", size: 22))
                    }
                    .padding(.bottom)
                } else {
                    Button(action: {
                        onComplete()
                    }) {
                        Text("구역 확장 끝내기")
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
                       let url = URL(string: urlString) {
                        self.routeImageURL = url
                    }
                }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🧪 runRecords 강제 세팅: \(runRecordVM.runRecords.count)")
                if let latest = runRecordVM.runRecords.first {
                    currentRecord = latest
                }
            }
            
            runRecordVM.fetchRunRecordsFromFirestore()

            // 0.2초 뒤에 최신 기록을 세팅
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print(runRecordVM.runRecords.count)

                if let latest = runRecordVM.runRecords.first {
                    currentRecord = latest
                    print("✅ currentRecord 설정됨 (onAppear): \(latest)")
                } else {
                    print("❌ 기록이 없음")
                }
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
}

#Preview {
    RunResultModalView(
        onComplete: {
            print("구역 확장 결과 모달 버튼 클릭")
        },
        hasReward: true
    )
    //    .onAppear {
    //        // Firebase에서 데이터 불러오기
    //        let runRecordVM = RunRecordViewModel()
    //        runRecordVM.fetchRunRecordsFromFirestore()
    //    }
    .environmentObject(RunRecordViewModel())
}
