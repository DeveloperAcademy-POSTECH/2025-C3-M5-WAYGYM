//
//  CustomNavigationBar.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/3/25.
//
import SwiftUI

struct CustomNavigationBar: View {
    @EnvironmentObject var coordinator: AppCoordinator
    let title: String

    var body: some View {
        ZStack {
            Color("gang_bg_profile")
                .ignoresSafeArea()
            
            HStack {
                Button(action: { coordinator.pop() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                }
                .padding(.leading, 15)
                Spacer()
            }
            
            HStack {
                Spacer()
                Text(title)
                    .font(.title01)
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }
}
