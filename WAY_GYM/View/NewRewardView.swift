//
//  NewRewardView.swift
//  Noter_C3
//
//  Created by soyeonsoo on 6/1/25.
//

import SwiftUI

struct NewRewardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("NEW")
                .font(.largeTitle01)
                .foregroundColor(.yellow)
            
            Image("weapon_1") // 보상 이미지
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .shadow(color: Color.yellow.opacity(0.8), radius: 26)
            
            Text("새로운 무기를 얻었다!")
                .font(.title01)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
        .ignoresSafeArea()
    }
}

#Preview {
    NewRewardView()
}
