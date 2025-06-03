//
//  MinionSingleView.swift
//  Ch3Personal
//
//  Created by 이주현 on 5/31/25.
//

import SwiftUI
import FirebaseFirestore

struct MinionSingleView: View {
    let minion: MinionDefinitionModel
    @StateObject private var minionVM = MinionViewModel()
    @StateObject private var userVM = UserViewModel()
    
    var body: some View {
        VStack {
            Image(minion.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150)
            
            VStack {
                HStack {
                    Text(minion.name)
                    Spacer()
                    Text(String(format: "%.0f km", minion.unlockNumber))
                }
                Text(minion.description)
                HStack {
                    Spacer()
                    if let date = minionVM.acquisitionDate(for: minion, in: userVM.user.runRecords) {
                        Text("획득 날짜: \(formatDate(date))")
                    }
                }
            }
            .border(Color.black, width: 2)
        }
    }
}

#Preview {
    MinionSingleView(minion: MinionDefinitionModel(
        id: "minion_1",
        name: "똘똘이",
        description: "5km 달성 시",
        iconName: "minion_1",
        unlockNumber: 5
    ))
}
