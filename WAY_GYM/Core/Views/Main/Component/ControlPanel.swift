//
//  ControlPanel.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/9/26.
//

import SwiftUI

struct ControlPanel: View {
    let runPhase: RunPhase

    /// 사용자 제스쳐 (로직은 메인뷰모델에서 처리)
    let onTapStartRun: () -> Void
    let onBeginFinishHold: () -> Void
    let onEndFinishHold: () -> Void
    let onTapMyLocation: () -> Void
    let onTapToggleCapturedArea: () -> Void
    
    let isAreaActive: Bool
    @State private var isLocationActive = false
    @State private var didStartHold: Bool = false

    var body: some View {
        ZStack {
            if case .finishing(let progress) = runPhase {
                finishingTipBox(progress: progress)
            }

            VStack {
                HStack {
                    Spacer()

                    VStack(spacing: 25) {
                        myLocationButton

                        /// 차지한 영역 버튼 (기본 화면에서만 노출)
                        if runPhase == .root {
                            capturedAreaButton
                        }
                    }
                    .padding(.trailing, 16)
                }

                Spacer()

                buttomRunButton
            }
        }
    }
    
    private func finishingTipBox(progress: CGFloat) -> some View {
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
                .frame(width: 350 * progress, height: 50)

            Text("길게 눌러서 땅따먹기 종료")
                .foregroundColor(.white)
                .font(.title02)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 36)
        }
        .padding(.horizontal, 34)
        .padding(.top, 20)
        .position(x: UIScreen.main.bounds.width / 2, y: 120)
        .ignoresSafeArea()
        .zIndex(1)
    }
    
    private var capturedAreaButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                onTapToggleCapturedArea()
            }) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isAreaActive ? Color.yellow : Color.black)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "map.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundColor(isAreaActive ? .black : .yellow)
                    )
            }

            Text("차지한\n영역")
                .multilineTextAlignment(.center)
                .font(.text02)
                .foregroundColor(isAreaActive ? .yellow : .white)
        }
    }

    private var myLocationButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                onTapMyLocation()
                isLocationActive.toggle()
            }) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLocationActive ? Color.yellow : Color.black)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "location.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundColor(isLocationActive ? .black : .yellow)
                    )
            }

            Text("내 위치")
                .font(.text02)
                .foregroundColor(isLocationActive ? .yellow : .white)
        }
    }
    
    private var buttomRunButton: some View {
        HStack {
            Spacer()
            switch runPhase {
            case .root, .countingDown:
                Button(action: {
                    onTapStartRun()
                }) {
                    Image("startButton")
                        .resizable()
                        .frame(width: 86, height: 86)
                }

            case .running, .finishing, .runResult:
                Circle()
                    .fill(Color.white)
                    .frame(width: 86, height: 86)
                    .overlay(
                        Text("◼️")
                            .font(.system(size: 38))
                            .foregroundColor(.black)
                    )
                    .contentShape(Circle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if runPhase == .running && !didStartHold {
                                    didStartHold = true
                                    onBeginFinishHold()
                                }
                            }
                            .onEnded { _ in
                                if runPhase == .running || ( { if case .finishing = runPhase { return true } else { return false } }() ) {
                                    didStartHold = false
                                    onEndFinishHold()
                                } else {
                                    didStartHold = false
                                }
                            }
                    )
            }

            Spacer()
        }
    }
}
