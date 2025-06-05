//
//  MainViewButtons.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/4/25.
//

import SwiftUI

struct ResultModalTestView: View {
    @State private var showResult = false
    @State private var navigateToMain = false
    @State private var holdProgress: CGFloat = 0.0  // 꾹 누름 게이지 진행 상태를 0.0 ~ 1.0 사이로 나타내는 변수, progress bar의 너비로 사용
    @State private var isHolding: Bool = false
    @State private var showTipBox: Bool = false
    @State private var showReward: Bool = false

    var body: some View {

        NavigationStack {
            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {

                    Text("걷는 중 화면(테스트 용)")
                        .font(.title)
                        .padding()
                    Spacer()
                    HStack {
                        
                        VStack(spacing: 4) {
                            Text("0:00")
                                .font(.title01)
                            Text("진행 시간")
                                .font(.title02)
                        }
                        .padding(.leading, 24)
                        .foregroundStyle(.white)

                        Spacer()

                        Circle()
                            .fill(isHolding ? Color.yellow : Color.white)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("◼️")
                                    .font(.system(size: 38))
                                    .foregroundColor(.black)
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isHolding {
                                            isHolding = true
                                            showTipBox = true
                                            startFilling()
                                        }
                                    }
                                    .onEnded { _ in
                                        isHolding = false
                                        holdProgress = 0.0

                                        if holdProgress >= 1.0 {
                                            showResult = true
                                        } else {
                                            holdProgress = 0.0
                                        }
                                    }
                            )
                            .padding(.trailing, 18)

                        Spacer()

                        Button(action: {
                            // 상세 달리기 정보 보기
                        }) {
                            Circle()
                                .fill(Color.modalBackground)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "chevron.up")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20, weight: .bold))
                                )
                        }
                        .padding()
                        .padding(.trailing, 12)
                    }
                    .padding(.top, 24)
                    .background(.secondary)
//                    .cornerRadius(20) // 위쪽만 radius 주는 게 어렵내
                }
                VStack {
                    Spacer()

                }

                // MARK: "길게 눌러서 땅따먹기 종료"
                if showTipBox {
                    VStack {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 350, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.yellow, lineWidth: 2)
                                )
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.yellow)
                                .frame(width: 350 * holdProgress, height: 50)

                            Text("길게 눌러서 땅따먹기 종료")
                                .foregroundColor(.white)
                                .font(
                                    .custom(
                                        "NeoDunggeunmoPro-Regular",
                                        size: 20
                                    )
                                )
                                .frame(height: 36)
                                .padding(.horizontal)
                        }
                        .padding(.top, 60)

                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
                    .alignmentGuide(.top) { _ in 0 }
                    .ignoresSafeArea()
                    .zIndex(1)
                }
            }

        }
//        .fullScreenCover(isPresented: $showResult) {
//            ZStack {
//                ResultModalView(capture: LandCapture.dummyData[5]) {
//                    showResult = false
//                    navigateToMain = true
//                }
//
//                if showReward {
//                    NewRewardView()
//                        .transition(.opacity)
//                        .onAppear {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 3)
//                            {
//                                showReward = false
//                            }
//                        }
//                }
//            }
//        }

    }

    func startFilling() {  // 0.05초마다 holdProgress 증가시킴, isHolding == true일 때만 동작
        // 게이지가 1.0에 도달하면 DispatchQueue.main.async 안에서 showResult = true 호출
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if isHolding {
                holdProgress += 0.03
                if holdProgress >= 1.0 {
                    timer.invalidate()
                    holdProgress = 1.0

                    DispatchQueue.main.async {
                        showResult = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showReward = true
                        }
                    }

                }
            } else {
                timer.invalidate()
                holdProgress = 0.0
            }
        }
    }
}

#Preview {
    ResultModalTestView()
}
