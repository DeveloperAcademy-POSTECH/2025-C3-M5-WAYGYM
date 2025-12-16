//
//  RunHistoryViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/19/25.
//

import Foundation

@MainActor
final class RunHistoryViewModel: ObservableObject {
    @Published var items: [RunCardModel] = []
    @Published var error: String?
    @Published var selected: RunDetailModel?
    @Published var isLoading: Bool = false

    func loadAllRuns() {
        isLoading = true
        Task {
            defer { self.isLoading = false }
            do {
                self.items = try await RunCardModel.fetchRunSummary()
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

    var sections: [RunHistorySection] {
        let grouped = Dictionary(grouping: items) { (item) -> MonthKey in
            MonthKey(date: item.startTime)
        }

        let sections = grouped.map { (key, runs) -> RunHistorySection in
            let totalArea = runs.reduce(0) { $0 + $1.capturedArea }
            let totalDistance = runs.reduce(0) { $0 + $1.distance }
            return RunHistorySection(
                id: key.rawValue,
                monthLabel: key.label,
                runs: runs.sorted(by: { $0.startTime > $1.startTime }),
                totalArea: totalArea,
                totalDistance: totalDistance
            )
        }

        // 최신 월부터 정렬
        return sections.sorted(by: { $0.sortKey > $1.sortKey })
    }
}

// MARK: - Section / Key Models
struct RunHistorySection: Identifiable {
    let id: String
    let monthLabel: String
    let runs: [RunCardModel]
    let totalArea: Double
    let totalDistance: Double

    // 정렬을 위한 키 (yyyyMM 숫자)
    var sortKey: Int {
        let comps = monthLabel.split(separator: " ")
        // monthLabel: "yyyy년 M월" 가정
        // 안전하게 숫자만 추출
        let year = Int(comps.first?.filter({ $0.isNumber }) ?? "0") ?? 0
        let month = Int(comps.last?.filter({ $0.isNumber }) ?? "0") ?? 0
        return year * 100 + month
    }
    
    var runCountText: String {
        "구역순찰 \(runs.count)회"
    }

    var totalAreaText: String {
        "\(Int(totalArea))m²"
    }

    var totalDistanceText: String {
        "\(String(format: "%.2f", totalDistance / 1000))km"
    }
    
}

private struct MonthKey: Hashable {
    let year: Int
    let month: Int

    init(date: Date) {
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: "Asia/Seoul") ?? .current
        var comps = cal.dateComponents(in: tz, from: date)
        self.year = comps.year ?? 0
        self.month = comps.month ?? 0
    }

    var label: String {
        "\(year)년 \(month)월"
    }

    var rawValue: String { label }
}
