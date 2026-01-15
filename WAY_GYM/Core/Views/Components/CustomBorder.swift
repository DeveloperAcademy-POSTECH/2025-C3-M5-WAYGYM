//
//  CustomBorder.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/7/25.
//

import SwiftUI

struct CustomBorderModifier: ViewModifier {
    let color: Color
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    
    init(
        color: Color = .black,
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = 16
    ) {
        self.color = color
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(color)
                        .frame(height: lineWidth)
                    Spacer()
                    Rectangle()
                        .fill(color)
                        .frame(height: lineWidth*2)
                }
                .padding(.horizontal, lineWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color, lineWidth: lineWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func customBorder(
        color: Color = .black,
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(
            CustomBorderModifier(
                color: color,
                lineWidth: lineWidth,
                cornerRadius: cornerRadius
            )
        )
    }
}
