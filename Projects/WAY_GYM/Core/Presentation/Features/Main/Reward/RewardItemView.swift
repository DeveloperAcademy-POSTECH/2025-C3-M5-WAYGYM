//
//  WeaponRewardView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/3/25.
//
import SwiftUI

struct RewardItemView: View {
    let type: RewardType
    let isLast: Bool
    let onDismiss: () -> Void

    var body: some View {
        let imageName: String
        let message: String

        switch type {
        case .weapon(let weapon):
            imageName = weapon.imageName
            message = "새로운 무기를 얻었다!"
        case .minion(let minion):
            imageName = minion.iconName
            message = "새로운 똘마니가 생겼다!"
        }

        return ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("NEW")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 44))
                    .foregroundColor(.yellow)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .shadow(color: Color.yellow.opacity(0.8), radius: 26)

                Text(message)
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 24))
                    .foregroundColor(.yellow)

                Button(action: { onDismiss() }) {
                    Text(isLast ? "돌아가기" : "다음")
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
