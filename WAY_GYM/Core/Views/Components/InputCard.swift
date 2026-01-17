//
//  InputCard.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/16/26.
//

import SwiftUI

struct InputCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    InputCard {
        Text("Hello")
            .foregroundStyle(Color.gangText2)
    }
}
