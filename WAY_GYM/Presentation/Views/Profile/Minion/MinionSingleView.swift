//
//  MinionSingleView.swift
//  Ch3Personal
//
//  Created by 이주현 on 5/31/25.
//

import SwiftUI
import FirebaseFirestore

struct MinionSingleView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var minionModel: MinionModel
    let minionIndex: Int
    @State private var acquisitionDate: Date? = nil
    
    var body: some View {
        ZStack {
            Color.gang_bg_primary_4
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button {
                        coordinator.pop()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.gang_text_2)
                            .font(.system(size: 30))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(25)
            
            VStack {
                ZStack {
                    Image("Flash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 220)
                    
                    Image(minionModel.allMinions[minionIndex].iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200)
                        .padding(.bottom, -20)
                }
                .padding(.bottom, 20)
                
                
                VStack(spacing: 16) {
                    HStack {
                        Text(minionModel.allMinions[minionIndex].name)
                    }
                    .padding(.horizontal, 10)
                    
                    Text(minionModel.allMinions[minionIndex].description)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Spacer()
                        
                        if let date = acquisitionDate {
                            Text("\(formatShortDate(date))")
                                .font(.text01)
                        }
                    }
                }
                .padding(20)
                .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gang_bg_secondary_2, lineWidth: 3)
                    )
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            // TODO: 서버에서 미니언 정보 받아오기
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    MinionSingleView(
        minionModel: MinionModel(),
        minionIndex: 0
    )
    .foregroundStyle(Color.gang_text_2)
    .font(.title01)
}
