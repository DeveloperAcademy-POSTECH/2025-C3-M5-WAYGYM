//
//  ControlPanel.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/9/26.
//

import SwiftUI

struct ControlPanel: View {
    let runPhase: RunPhase
    let activeDuoWorldId: String?
    let duoOwnedCellCount: Int
    let duoOpponentCellCount: Int
    let duoEndsAt: Date?
    let shouldShowModeBadge: Bool

    /// 사용자 제스쳐 (로직은 메인뷰모델에서 처리)
    let onTapStartRun: () -> Void
    let onBeginFinishHold: () -> Void
    let onEndFinishHold: () -> Void
    let onTapMyLocation: () -> Void
    let onTapToggleCapturedArea: () -> Void
    let onTapGoFriendList: () -> Void
    
    let isAreaActive: Bool
    @State private var isLocationTapped = false
    @State private var didStartHold: Bool = false
    @State private var showSoloModeTip: Bool = false
    @State private var countdownNow = Date()
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isDuoMode: Bool {
        activeDuoWorldId != nil
    }

    private var duoResultLabel: String {
        if duoOwnedCellCount > duoOpponentCellCount { return "WIN" }
        if duoOwnedCellCount < duoOpponentCellCount { return "LOSE" }
        return "EVEN"
    }

    private var duoRatioText: String {
        let total = duoOwnedCellCount + duoOpponentCellCount
        guard total > 0 else { return "0:0" }
        let myRatio = Int((Double(duoOwnedCellCount) / Double(total) * 100).rounded())
        let opponentRatio = max(0, 100 - myRatio)
        return "\(myRatio):\(opponentRatio)"
    }

    private var duoStatusText: String {
        if duoOwnedCellCount > duoOpponentCellCount { return "이기고 있습니다!" }
        if duoOwnedCellCount < duoOpponentCellCount { return "지고 있습니다!" }
        return "팽팽합니다!"
    }

    private var duoRemainingTimeText: String? {
        guard let duoEndsAt else { return nil }
        let remaining = max(0, Int(duoEndsAt.timeIntervalSince(countdownNow)))
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d:%02d:%02d", days, hours, minutes, seconds)
    }

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

                if shouldShowModeBadge {
                    modeBadge
                        .padding(.bottom, 8)
                }
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
    
    private var modeBadge: some View {
        VStack(spacing: 8) {
            if showSoloModeTip {
                modeTipBubble
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                Image(systemName: isDuoMode ? "person.2.fill" : "figure.run")
                    .font(.system(size: 12, weight: .bold))
                VStack(alignment: .center, spacing: 1) {
                    Text(isDuoMode ? "경쟁 MODE • \(duoResultLabel)" : "개인 MODE")
                        .font(.text01)
                        .kerning(0.5)
                    if isDuoMode, let remaining = duoRemainingTimeText {
                        Text("\(remaining)")
                            .font(.text02)
                    }
                }
            }
            .foregroundColor(isDuoMode ? .black : .yellow)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isDuoMode ? Color.red : Color.black.opacity(0.78))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .padding(2)
            )
            .shadow(color: isDuoMode ? Color.red.opacity(0.28) : Color.black.opacity(0.45), radius: 8, y: 3)
            .contentShape(Capsule(style: .continuous))
            .onTapGesture {
                if showSoloModeTip {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSoloModeTip = false
                    }
                    return
                }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    showSoloModeTip = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSoloModeTip = false
                    }
                }
            }
            .onReceive(countdownTimer) { date in
                countdownNow = date
            }
        }
    }

    private var modeTipBubble: some View {
        VStack(spacing: 4) {
            if isDuoMode {
                Text("\(duoRatioText)으로 \(duoStatusText)")
                    .font(.text02)
                    .foregroundColor(.yellow)
            } else {
                Text("친구를 맺어 경쟁전을 플레이해보세요!")
                    .font(.text02)
                    .foregroundColor(.yellow)

                Button(action: {
                    onTapGoFriendList()
                    showSoloModeTip = false
                }) {
                    Text("친구 목록으로 가기")
                        .font(.text02)
                        .foregroundColor(.gray)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(
            ModeTipBubbleShape(cornerRadius: 12, pointerWidth: 16, pointerHeight: 8)
                    .fill(Color.black.opacity(0.92))
            )
            .overlay(
                ModeTipBubbleShape(cornerRadius: 12, pointerWidth: 16, pointerHeight: 8)
                    .stroke(Color.yellow.opacity(0.9), lineWidth: 1.5)
            )
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
                isLocationTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLocationTapped = false
                }
            }) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLocationTapped ? Color.yellow : Color.black)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "location.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundColor(isLocationTapped ? .black : .yellow)
                    )
            }

            Text("내 위치")
                .font(.text02)
                .foregroundColor(isLocationTapped ? .yellow : .white)
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

private struct ModeTipBubbleShape: Shape {
    let cornerRadius: CGFloat
    let pointerWidth: CGFloat
    let pointerHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, (rect.height - pointerHeight) / 2)
        let bodyMaxY = rect.maxY - pointerHeight
        let midX = rect.midX
        let pointerHalfWidth = pointerWidth / 2

        var path = Path()

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyMaxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: bodyMaxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: midX + pointerHalfWidth, y: bodyMaxY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - pointerHalfWidth, y: bodyMaxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: bodyMaxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: bodyMaxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
