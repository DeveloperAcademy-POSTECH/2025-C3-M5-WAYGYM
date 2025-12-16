//
//  RootView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//

import SwiftUI

struct RootView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationStack {
            switch router.currentScreen {
            case .main(let id):
                        MainView(locationManager: locationManager)
                            .id(id)
                            .environmentObject(router)
                            .environmentObject(LocationManager())
                
//            case .result(_):
//                AnyView(RunResultModalView(
//                    capture: RunRecordModel.dummyData[5],
//                    onComplete: {
//                        router.currentScreen = .main
//                    },
//                    hasReward: true // 조건에 맞는 값 필요
//                ))
            case .profile:
                AnyView( ProfileView()
                        .environmentObject(router)
                        .environmentObject(MinionViewModel())
                        .environmentObject(WeaponViewModel())
                        .environmentObject(RunRecordViewModel())
                        .font(.text01)
                        .foregroundColor(Color("gang_text_2"))
                         .navigationBarHidden(true)
                )
//            case .weaponReward(let weapon):
//                AnyView(
//                    WeaponRewardView(weapon: weapon)
//                        .environmentObject(router)
//                )
//                
//            case .minionReward(let minion):
//                AnyView(MinionRewardView(minion: minion)
//                    .environmentObject(router)
//                )
            }
        }
    }
}


struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
