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
                case .result(_):
                    RunResultModalView(capture: RunRecordModel.dummyData[5]) {
                        router.currentScreen = .main
                    }
                case .profile:
<<<<<<< HEAD
                    ProfileView()
                        .environmentObject(router)
                        .environmentObject(MinionViewModel())
                        .environmentObject(WeaponViewModel())
                        .font(.text01)
                        .foregroundColor(Color("gang_text_2"))
=======
                    ProfileView().environmentObject(router)
>>>>>>> develop
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
