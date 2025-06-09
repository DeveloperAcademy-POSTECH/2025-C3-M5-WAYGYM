//
//  RunResultTestView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/5/25.
//

import SwiftUI

struct RunResultTestView: View {
    @StateObject private var weaponVM = WeaponViewModel()
    @StateObject private var runRecordVM = RunRecordViewModel()
    @State private var showResultModal = false
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            Image("SampleMap")
                .ignoresSafeArea()
            Button {
                showResultModal = true
                // router.currentScreen = .main
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
                        .environmentObject(runRecordVM)
                        .environmentObject(weaponVM)
                        .environmentObject(router)
                }
            }
        })
        
    }
}

#Preview {
    RunResultTestView()
}
