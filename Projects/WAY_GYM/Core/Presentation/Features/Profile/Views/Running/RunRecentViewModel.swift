//
//  RunRecentViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/18/25.
//

import Foundation

@MainActor
final class RunRecentViewModel: ObservableObject {
    @Published var items: [RunCardModel] = []
    @Published var error: String?
    @Published var selected: RunDetailModel?

    var isRunHistoryEmpty: Bool {
        items.isEmpty
    }
    
    func loadRecentFiveRuns() {
        Task {
            do {
                self.items = try await RunCardModel.fetchRunSummary().prefix(5).map { $0 }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func selectCard(_ card: RunCardModel) {
        Task {
            do {
                self.selected = try await RunDetailModel.fetch(byId: card.id)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
}
