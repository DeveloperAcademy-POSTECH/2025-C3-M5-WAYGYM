//
//  CountdownOverlay.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/9/26.
//

import SwiftUI

struct CountdownOverlay: View {
    let countdown: Int
    
    var body: some View {
        Color.gang_start_bg
            .edgesIgnoringSafeArea(.all)
            .overlay(
                Text("\(countdown)")
                    .font(.countdown)
                    .foregroundColor(Color.gang_highlight_2)
            )
            .transition(.opacity)
    }
}
