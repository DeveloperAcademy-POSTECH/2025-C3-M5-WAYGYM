//
//  RunResultTestView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/5/25.
//

import SwiftUI

struct RunResultTestView: View {
    @StateObject private var weaponVM = WeaponViewModel()
    @State private var showResultModal = false
    @EnvironmentObject var router: AppRouter

    var body: some View {
            VStack {
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
            .sheet(isPresented: $showResultModal) {
                RunResultModalView(
                    onComplete: {}
                )
                    .environmentObject(weaponVM)
                    .environmentObject(router)
            }
        
    }
}

#Preview {
    RunResultTestView()
}
