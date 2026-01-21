//
//  RefreshErrorBanner.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import SwiftUI

struct RefreshErrorBanner: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 18, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text("새로고침 실패")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(message)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    RefreshErrorBanner(message: "실패") {
        //
    }
}
