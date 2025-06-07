//
//  CustomBorder.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/7/25.
//

import SwiftUI

struct CustomBorderModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .overlay(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                    Spacer()
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 4)
                }
                .padding(.horizontal, 2)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.black, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
extension View {
    func customBorder(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(CustomBorderModifier(cornerRadius: cornerRadius))
    }
}
