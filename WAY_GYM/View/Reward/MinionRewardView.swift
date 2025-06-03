//
//  MinionRewardView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/4/25.
//


import SwiftUI

struct MinionRewardView: View {
    let minion: MinionDefinitionModel
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("NEW")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 44))
                    .foregroundColor(.yellow)

                Image(minion.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .shadow(color: Color.yellow.opacity(0.8), radius: 26)

                Text("새로운 똘마니가 생겼다!")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 24))
                    .foregroundColor(.yellow)

                Button(action: {
                    router.currentScreen = .main
                }) {
                    Text("돌아가기")
                        .font(.custom("NeoDunggeunmoPro-Regular", size: 20))
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: 240)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.top, 30)
            }
            .padding()
        }
    }
}

#Preview {
    let model = MinionModel()
    return MinionRewardView(
        minion: model.allMinions[1]
    )
    .environmentObject(AppRouter())
}

