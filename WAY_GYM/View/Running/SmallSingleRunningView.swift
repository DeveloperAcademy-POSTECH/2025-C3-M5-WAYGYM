//
//  SingleRunninView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/4/25.
//

import SwiftUI

struct SmallSingleRunningView: View {
    var body: some View {
        ZStack {
            Color.gang_bg_primary_5
                .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: 16) {
                HStack {
                    Image("route_1") // 달리기 이미지
                        .resizable()
                        .frame(width: 96, height: 96)
                        .border(Color.black, width: 1)
                        .padding(.trailing, 16.0)
                    
                    Text("00.00m²") // 땅따먹은 수치
                    
                    Spacer()
                }
                
                HStack(spacing: 30) {
                    VStack(spacing: 10) {
                        Text("소요시간")
                            .font(.text01)
                            .foregroundStyle(Color.text_secondary)
                        Text("24:24")
                    }
                    
                    VStack(spacing: 10) {
                        Text("거리")
                            .font(.text01)
                            .foregroundStyle(Color.text_secondary)
                        Text("2.86km")
                    }
                    VStack(spacing: 10) {
                        Text("칼로리")
                            .font(.text01)
                            .foregroundStyle(Color.text_secondary)
                        Text("132kcal")
                    }
                }
            }
            .foregroundStyle(Color.text_primary)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(.white)
            .cornerRadius(16)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .inset(by: 1)
                    .stroke(Color.gang_bg_secondary_2, lineWidth: 2)
            )
            .overlay(
                Text("25.05.20 18:05")
                    .foregroundStyle(Color.text_secondary)
                    .font(.text01)
                    .padding(20),alignment: .topTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    SmallSingleRunningView()
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
}
