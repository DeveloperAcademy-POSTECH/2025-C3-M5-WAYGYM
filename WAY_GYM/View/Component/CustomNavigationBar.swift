//
//  CustomNavigationBar.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/3/25.
//
import SwiftUI

struct CustomNavigationBar: View {
    let title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.gray
                .ignoresSafeArea()
            
            HStack {
                Button(action: { dismiss() }) {
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
        .frame(width: .infinity)
        .frame(height: 50)
    }
}
