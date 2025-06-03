//
//  RunResultModalView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 5/31/25.
//

import SwiftUI

struct RunResultModalView: View {
    let capture: RunRecordModel
    let onComplete: () -> Void
    let hasReward: Bool // 보상 유무

    var body: some View {
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
            
                if let imageName = capture.routeImage{
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
                
                Text("\(String(format: "%.1f", capture.capturedAreaValue))m²")
                    .font(.largeTitle02)
                    .foregroundColor(.white)
                    .padding(.top, -20)


                Spacer().frame(height: 0)

                
                HStack(spacing: 50){
                    VStack(spacing: 8) {
                        Text("시간")
                        Text(formatDuration(capture.duration))
                    }
                    VStack(spacing: 8) {
                        Text("거리")
                        Text(String(format: "%.1f km", capture.totalDistance / 1000))
                    }
                    VStack(spacing: 8) {
                        Text("칼로리")
                        Text("\(Int(capture.caloriesBurned))kcal")
                    }
                }
                .font(.title03)
                .foregroundColor(.white)
                
                Spacer().frame(height: 0)
                if hasReward{
                    Button(action: {
                        onComplete()
                    }) {
                        Text("보상 확인하기")
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gang_yellow)
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
                            .background(Color.gang_yellow)
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
                    .stroke(Color.gang_yellow.opacity(0.8), lineWidth: 2)
            )
            .frame(maxWidth: 340, maxHeight: 660)

        }
    }
    private func formatDuration(_ duration: TimeInterval) -> String{
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
}

#Preview {
    RunResultModalView(capture: RunRecordModel.dummyData[5], onComplete: {}, hasReward: true)
}

