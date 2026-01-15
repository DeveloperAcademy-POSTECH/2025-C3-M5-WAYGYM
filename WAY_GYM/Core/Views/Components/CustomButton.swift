//
//  CustomButton.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI

enum CustomButtonStyle {
    case small      // 텍스트 버튼
    case compact    // 낮은 높이
    case regular    // 기본
}

struct CustomButton: View {
    let title: String
    let action: () -> Void
    
    var style: CustomButtonStyle = .regular
    var isDisabled: Bool = false
    var isLoading: Bool = false
    var systemImage: String? = nil
    
    private var isButtonDisabled: Bool {
        isDisabled || isLoading
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .disabled(isButtonDisabled)
        .opacity(isButtonDisabled ? 0.45 : 1)
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .small:
            Group {
                if let systemImage {
                    HStack(spacing: 2) {
                        Image(systemName: systemImage)
                        Text(title)
                    }
                } else {
                    Text(title)
                }
            }
            .font(.text02)
            .foregroundStyle(Color.black)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.gangHighlight2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gangBlackOpacity, lineWidth: 2)
            )

        case .compact:
            baseCardButton(height: 44)

        case .regular:
            baseCardButton(height: 55)
        }
    }

    private func baseCardButton(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gangHighlight2)

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gangBlackOpacity, lineWidth: 2)

            HStack(spacing: 8) {
                Text(title)
                    .font(.title02)
                    .foregroundStyle(Color.gangBlack)

                if isLoading {
                    ProgressView()
                        .foregroundStyle(Color.gangText2)
                }
            }
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.bottom, 5)
    }
}

#Preview {
    VStack(spacing: 16) {
        // 1) small
        CustomButton(title: "내위치", action: { }, style: .small)

        // 2) compact
        CustomButton(title: "중복확인", action: { }, style: .compact)

        // 3) regular
        CustomButton(title: "구역 확장하러 가기", action: { }, style: .regular)

        // loading (compact)
        CustomButton(title: "전송 중...", action: { }, style: .compact, isDisabled: false, isLoading: true)

        // disabled (regular)
        CustomButton(title: "비활성", action: { }, style: .regular, isDisabled: true)
    }
    .padding()
}
