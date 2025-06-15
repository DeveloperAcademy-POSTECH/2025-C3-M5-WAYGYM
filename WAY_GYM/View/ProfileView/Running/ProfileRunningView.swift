//
//  Practicew.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/8/25.
//

import SwiftUI

struct ProfileRunningView: View {
    @EnvironmentObject private var runRecordVM: RunRecordViewModel
    // @State private var topSummaries: [RunSummary] = []
    @State private var topSummaries: [RunSummaryProfile] = []
    @State private var selectedSummary: RunSummary? = nil
    @State private var isDetailActive: Bool = false


    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if topSummaries.isEmpty {
                    VStack(alignment: .center) {
                        Text("이런...!\n내 구역이 없잖아?!")
                        Text("\n구역확장을 해야겠어...!")
                    }
                    .padding(5)
                    .font(.text01)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                } else {
                    ForEach(topSummaries.prefix(5)) { summary in
                        SummaryCardView(summary: summary) { tapped in
                            runRecordVM.fetchRunSummary(by: tapped.id) { fullSummary in
                                if let summary = fullSummary {
                                    self.selectedSummary = summary
                                    self.isDetailActive = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            runRecordVM.fetchAllProfileRunSummaries { allSummaries in
                self.topSummaries = Array(allSummaries.sorted(by: { $0.startTime > $1.startTime }).prefix(5))
            }
        }
        
        NavigationLink(
            destination: selectedSummary.map { summary in
                AnyView(
                    BigSingleRunningView(summary: summary)
                        .foregroundColor(Color.gang_text_2)
                        .font(.title01)
                )
            } ?? AnyView(EmptyView()),
            isActive: $isDetailActive,
            label: {
                EmptyView()
            }
        )
        .hidden()
        
    }
}

struct SummaryCardView: View {
    let summary: RunSummaryProfile
    let onTap: (RunSummaryProfile) -> Void

    var body: some View {
//        let destinationView = BigSingleRunningView(summary: summary)
//            .foregroundColor(Color.gang_text_2)
//            .font(.title01)

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

//        return NavigationLink(destination: destinationView) {
        return Button(action: {
            onTap(summary)
        }) {
            contentView
        }
    }
}

#Preview {
    ProfileRunningView()
        .environmentObject(RunRecordViewModel())
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
}
