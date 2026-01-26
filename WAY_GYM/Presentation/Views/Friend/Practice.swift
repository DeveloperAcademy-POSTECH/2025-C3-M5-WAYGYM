//
//  Practice.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import SwiftUI

struct Practice: View {
    var body: some View {
        VStack {
            Spacer()
            Button {
                //
            } label: {
                Text("요청중")
                    .font(.text02)
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gang_highlight_3.opacity(0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gang_highlight_3.opacity(0.20), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Button {
                //
            } label: {
                Text("수락하기")
                    .font(.text02)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gang_highlight_2.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gang_highlight_2.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(width: .infinity, height: .infinity)
        .background {
            Color.gangBgPrimary5
                .ignoresSafeArea()
        }
    }
    
}

#Preview {
    Practice()
}
