//
//  RunResultTestView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/5/25.
//

import SwiftUI

struct RunResultTestView: View {
    @StateObject private var weaponVM = WeaponService()
    @StateObject private var runRecordVM = RunRecordService()
    @State private var showResultModal = false
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            Image("SampleMap")
                .ignoresSafeArea()
            
            Button {
                showResultModal = true
            } label: {
                Text("테스트 런닝 종료")
                    .font(.title)
                    .foregroundStyle(Color.black)
                    .overlay {
                        Rectangle()
                            .border(Color.black, width: 1)
                            .foregroundStyle(Color.clear)
                    }
            }

        }
        .overlay(content: {
            if showResultModal {
                ZStack {
                    Color.gang_black_opacity
                        .ignoresSafeArea()
                    
                    RunResultModalView(onComplete: { showResultModal = false })
                }
            }
        })
        
    }
}

#Preview {
    RunResultTestView()
}
