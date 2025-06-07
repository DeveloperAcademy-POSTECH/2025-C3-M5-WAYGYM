//
//  BigSingleRunningView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/4/25.
//

import SwiftUI

struct BigSingleRunningView: View {
    var body: some View {
        ZStack {
            Image("SampleMap")
                .resizable()
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack {
                    HStack {
                        customLabel(value: "0.00", title:
                                        "영역(m²)")
                        
                        Spacer()
                        
                        Text("2025.05.20\n08:40(수)")
                            .font(.text01)
                            .padding(.trailing, 16)
                    }
                    
                    Spacer()
                        .frame(height: 24)
                    
                    HStack {
                        customLabel(value: "14:40", title: "소요시간")
                        Spacer()
                        customLabel(value: "2.85", title: "거리(km)")
                        Spacer()
                        customLabel(value: "132.6", title: "칼로리")
                    }
                }
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(width: UIScreen.main.bounds.width)
                // .frame(height: 150)
                .frame(height: UIScreen.main.bounds.height * 0.21)
                .background(Color.gang_sheet_bg_opacity)
                .cornerRadius(16)
                
            }
            .ignoresSafeArea()
        }
    }
    
    struct customLabel: View {
        let value: String
        let title: String
        
        var body: some View {
            VStack {
                Text(value)
                    .font(.title01)
                Text(title)
                    .font(.title03)
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    BigSingleRunningView()
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
}
