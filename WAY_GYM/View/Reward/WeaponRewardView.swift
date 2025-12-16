//
//  WeaponRewardView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/3/25.
//
import SwiftUI

struct WeaponRewardView: View {
    let weapon: WeaponDefinitionModel
    let onDismiss: () -> Void
    let isLast: Bool
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("NEW")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 44))
                    .foregroundColor(.yellow)

                Image(weapon.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .shadow(color: Color.yellow.opacity(0.8), radius: 26)

                Text("새로운 무기를 얻었다!")
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 24))
                    .foregroundColor(.yellow)

                Button(action: {
                    onDismiss()
                }) {
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

#Preview {
    let model = WeaponModel()
    return WeaponRewardView(
        weapon: model.allWeapons[1],
        onDismiss: {},
        isLast: true
    )
    .environmentObject(AppRouter())
}
