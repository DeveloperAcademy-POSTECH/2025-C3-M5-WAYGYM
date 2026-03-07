//
//  ProfileRunningView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/8/25.
//

import SwiftUI

struct ProfileRunningView: View {
    @EnvironmentObject var runRecordStore: RunRecordStore
    @EnvironmentObject var coordinator: AppCoordinator
    private var topSummaries: [RunRecord] {
        Array(runRecordStore.runRecords.sorted(by: { $0.startTime > $1.startTime }).prefix(3))
    }

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
                    ForEach(Array(topSummaries.enumerated()), id: \.offset) { _, summary in
                        Button {
                            guard let runId = summary.id else {
                                return
                            }
                            coordinator.push(.runningDetail(runId))
                        } label: {
                            RunRecordCardView(summary: summary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileRunningView()
        .environmentObject(RunRecordStore())
        .environmentObject(AppCoordinator())
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
}
