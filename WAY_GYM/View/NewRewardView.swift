//
//  NewRewardView.swift
//  Noter_C3
//
//  Created by soyeonsoo on 6/1/25.
//

import SwiftUI

struct NewRewardView: View {
    let imageName: String
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("NEW")
                .font(.largeTitle01)
                .foregroundColor(Color.gangYellow)
            
            Image("weapon_1") // 보상 이미지
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .shadow(color: Color.gang_yellow.opacity(0.8), radius: 26)
            
            Text("새로운 무기를 얻었다!")
                .font(.title01)
                .foregroundColor(Color.gangYellow)
            
            Button(action: {
                onComplete()
            }) {
                Text("돌아가기")
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: 150)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .font(.custom("NeoDunggeunmoPro-Regular", size: 22))
            }
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
        .ignoresSafeArea()
    }
}

#Preview {
    NewRewardView(imageName: "minion_1", onComplete: {})
}
