//
//  RootView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//

import SwiftUI

struct RootView: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        NavigationStack {
            Group {
                switch router.currentScreen {
                case .main:
                    MainView().environmentObject(router)
                case .running:
                    RunningView().environmentObject(router)
                    
//                case .result(_):
//                    RunResultModalView(capture: RunRecordModels.dummyData[5]) {
//                        router.currentScreen = .main
//                    }
                    
                case .profile:
                    ProfileView()
                        .environmentObject(router)
                        .environmentObject(MinionViewModel(runRecordVM: RunRecordViewModel()))
                        .environmentObject(WeaponViewModel())
                        .environmentObject(RunRecordViewModel())
                        .font(.text01)
                        .foregroundColor(Color("gang_text_2"))

                }
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
