//
//  WAY_GYMApp.swift
//  WAY_GYM
//
//  Created by Leo on 5/27/25.
//

import SwiftUI

@main
struct WAY_GYMApp: App {
    var body: some Scene {
        WindowGroup {
            // 주디제이
            ProfileView()
                .environmentObject(MinionViewModel())
                .environmentObject(WeaponViewModel())
                .font(.text01)
                .foregroundColor(.white)
                 
            
            // 레오
            // ContentView()
        }
    }
}
