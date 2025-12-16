//
//  SummaryCardView.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/18/25.
//

import SwiftUI

struct RunCardView: View {
    let summary: RunCardModel
    let onTap: (RunCardModel) -> Void

    var body: some View {
        let imageView: some View = {
            if let url = summary.routeImageURL {
                return AnyView(
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Text("준비중")
                                .font(.text01)
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .padding(.trailing, 16)
                        case .success(let image):
                            image
                                .resizable()
                                .frame(width: 96, height: 96)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray, lineWidth: 1))
                                .padding(.trailing, 16)
                        case .failure:
                            Text("준비중")
                                .font(.text01)
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .padding(.trailing, 16)
                        @unknown default:
                            EmptyView()
                        }
                    }
                )
            } else {
                return AnyView(
                    Text("준비중")
                        .font(.text01)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding(.trailing, 16)
                )
            }
        }()

        let infoRow = HStack(spacing: 30) {
            InfoItem(title: "소요시간", content: "\(Int(summary.duration) / 60):\(String(format: "%02d", Int(summary.duration) % 60))")
            InfoItem(title: "거리", content: "\(String(format: "%.2f", summary.distance / 1000))km")
            InfoItem(title: "칼로리", content: "\(Int(summary.calories))kcal")
        }

        let contentView = VStack(alignment: .center, spacing: 16) {
            HStack {
                imageView
                Text("\(Int(summary.capturedArea))m²")
                Spacer()
            }
            infoRow
        }
        .foregroundColor(.text_primary)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gang_bg_secondary_2, lineWidth: 2)
        )
        .overlay(
            Text(summary.startTime.formattedDate())
                .font(.text01)
                .foregroundColor(.text_secondary)
                .padding(20),
            alignment: .topTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))

        return Button(action: {
            onTap(summary)
        }) {
            contentView
        }
    }
}

struct InfoItem: View {
    let title: String
    let content: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.text01)
                .foregroundColor(.text_secondary)
            Text(content)
                .foregroundColor(.text_primary)
        }
    }
}
