import SwiftUI
import UIKit

struct SplashLoadingView: View {
    let progress: Double
    let statusText: String

    private var progressPercent: Int {
        Int((max(0, min(1, progress)) * 100).rounded())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gang_start_bg, Color.gang_bg_primary_5, Color.gang_black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 25) {
                IconLogo()

                VStack(spacing: 14) {
                    Text(statusText)
                        .font(.text02)
                        .foregroundStyle(Color.gangText2)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.yellow)
                                .frame(width: geo.size.width * max(0, min(1, progress)))
                        }
                    }
                    .frame(height: 14)
                }
                .padding(14)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .frame(maxWidth: 320)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct IconLogo: View {
    @State private var currentMinionIndex: Int = Int.random(in: 1...10)
    private let minionRange = 1...10
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 17) {
                ZStack {
                    Color.black.opacity(0.4)
                    Image("Flash")
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                    Image("minion_\(currentMinionIndex)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90)
                        .padding(.top, 15)
                }
                .frame(width: 130, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 16, y: 8)
                
                
                Text("걸어서 내 영역을 확장해라!")
                    .font(.title02)
                    .foregroundStyle(Color.white)
            }
        .onReceive(timer) { _ in
            var next = currentMinionIndex
            while next == currentMinionIndex {
                next = Int.random(in: minionRange)
            }
            currentMinionIndex = next
        }
    }
}

#Preview("Splash - Loading 42%") {
    SplashLoadingView(
        progress: 0.42,
        statusText: "친구 정보 동기화 중..."
    )
}
