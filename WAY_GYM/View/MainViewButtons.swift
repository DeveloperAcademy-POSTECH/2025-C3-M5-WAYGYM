import SwiftUI

struct ResultModalTestView: View {
    @State private var showResult = false
    @State private var navigateToMain = false
    @State private var holdProgress: CGFloat = 0.0
    @State private var isHolding: Bool = false
    @State private var showTipBox: Bool = false
    @State private var showReward: Bool = false

    @State private var isLocationActive = false
    @State private var isAreaActive = false
    @State private var showDetailInfo = false // 상세 정보 보기 토글용
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Color.gray.ignoresSafeArea()

                VStack {
                    VStack(spacing: 14) {
                        VStack(spacing: 6) {
                            Button(action: {
                                isLocationActive.toggle()
                            }) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isLocationActive ? Color.yellow : Color.black)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "location.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(isLocationActive ? .black : .yellow)
                                    )
                            }
                            Text("내 위치")
                                .font(.text02)
                                .foregroundColor(isLocationActive ? .yellow : .white)
                        }

                        VStack(spacing: 6) {
                            Button(action: {
                                isAreaActive.toggle()
                            }) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isAreaActive ? Color.yellow : Color.black)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "map.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(isAreaActive ? .black : .yellow)
                                    )
                            }
                            Text("차지한 영역")
                                .font(.text02)
                                .foregroundColor(isAreaActive ? .yellow : .white)
                        }

                        Spacer().frame(width: 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    
                    Button(action: {
                        // 땅따먹기 시작
                    }) {
                        Circle()
                            .fill(Color.gangHighlight2)
                            .frame(width: 86, height: 86)
                            .overlay(
                                Image("start")
                                    .padding(.top, 2)
                                    .padding(.leading, 3)
                            )
                    
                    }

                    Spacer()

                    VStack(spacing: 0) {
                        if showDetailInfo {
                            HStack(spacing: 80) {
                                VStack(spacing: 24) {
                                    VStack {
                                        Text("132,911").font(.title01).foregroundColor(.white) // 실시간 영역 계산값
                                        Text("영역(m²)").font(.title01).foregroundColor(.gray)
                                    }
                                    VStack {
                                        Text("00:00").font(.title01).foregroundColor(.white) // 시간
                                        Text("진행 시간").font(.title01).foregroundColor(.gray)
                                    }
                                }

                                VStack(spacing: 24) {
                                    VStack {
                                        Text("3.21").font(.title01).foregroundColor(.white) // 실시간 거리값
                                        Text("거리(km)").font(.title01).foregroundColor(.gray)
                                    }
                                    VStack {
                                        Text("78.13").font(.title01).foregroundColor(.white) // 실시간 칼로리 계산값
                                        Text("kcal").font(.title01).foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.top, 30)
                            .cornerRadius(12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        HStack {
                            Group {
                                if !showDetailInfo {
                                    VStack(spacing: 4) {
                                        Text("0:00")
                                            .font(.title01)
                                        Text("진행 시간")
                                            .font(.title02)
                                    }
                                    .padding(.leading, 20)
                                    .foregroundStyle(.white)
                                } else {
                                    VStack {
                                        Text(" ")
                                        Text(" ")
                                    }
                                    .opacity(0)
                                }
                            }
                            .padding(.leading, 20)

                            Spacer()

                            Circle()
                                .fill(isHolding ? Color.yellow : Color.white)
                                .frame(width: 86, height: 86)
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
                                .padding(.trailing, 28)

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    showDetailInfo.toggle()
                                }
                            }) {
                                Circle()
                                    .fill(Color.modalBackground)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: showDetailInfo ? "chevron.down" : "chevron.up")
                                            .foregroundColor(.white)
                                            .font(.system(size: 20, weight: .bold))
                                    )
                            }
                            .padding()
                            .padding(.trailing, 12)
                        }
                        .padding(.top, 24)
                    }
                    .background(Color.secondary)
                }

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
    }

    func startFilling() {
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
