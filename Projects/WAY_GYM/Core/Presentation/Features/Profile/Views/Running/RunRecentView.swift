//
//  Practicew.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/8/25.
//

import SwiftUI

struct RunRecentView: View {
    @StateObject private var viewModel = RunRecentViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isRunHistoryEmpty {
                    VStack(alignment: .center) {
                        Text("이런...!\n내 구역이 없잖아?!")
                        Text("\n구역확장을 해야겠어...!")
                    }
                    .padding(5)
                    .font(.text01)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                } else {
                    ForEach(viewModel.items) { summary in
                        RunCardView(summary: summary) { tapped in
                            viewModel.selectCard(tapped)
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.loadRecentFiveRuns() }

        NavigationLink(
            destination: viewModel.selected.map { summary in
                AnyView(
                    RunDetailView(viewModel: RunDetailViewModel(summary: summary))
                        .foregroundColor(Color.gang_text_2)
                        .font(.title01)
                )
            } ?? AnyView(EmptyView()),
            isActive: Binding(
                get: { viewModel.selected != nil },
                set: { active in if !active { viewModel.selected = nil } }
            ),
            label: { EmptyView() }
        )
        .hidden()
        
    }
}

#Preview {
    RunRecentView()
        .foregroundColor(Color.gang_text_2)
        .font(.title01)
}
