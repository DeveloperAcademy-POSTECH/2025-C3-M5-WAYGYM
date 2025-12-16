//
//  MinionCard.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/14/25.
//

import SwiftUI

struct MinionCard: View {
    let minion: MinionDefinitionModel
    var isHighlighted: Bool = false
    
    var body: some View {
        ZStack {
            Image("minion_box")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.width * 0.25)
            
            VStack {
                Image(minion.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80)
                    .shadow(color: isHighlighted ? Color.yellow : Color.black, radius: 4)
                
                Text(minion.name)
                    .foregroundStyle(Color.black)
                
                Text(String(format: "%.0f km", minion.unlockNumber))
                    .foregroundColor(.black)
            }
            
        }
    }
}

struct LockedMinionCard: View {
    let minion: MinionDefinitionModel
    
    var body: some View {
        ZStack {
            Image("minion_box")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.width * 0.25)
            
            VStack {
                Image("questionMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80)
                    .shadow(color: Color.black, radius: 4, x: 0, y: 0)
                
                Text("???")
                    .foregroundStyle(Color.black)
                
                Text(String(format: "%.0f km", minion.unlockNumber))
                    .foregroundStyle(Color.black)
            }
        }
        .cornerRadius(8)
    }
}
