//
//  RunDetailViewModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/19/25.
//

import Foundation
import MapKit

@MainActor
final class RunDetailViewModel: ObservableObject {
    private let summary: RunDetailModel

    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published  var overlays: [MKOverlay] = []

    @Published var isLoading: Bool = false
    @Published var error: String?

    init(summary: RunDetailModel) {
        self.summary = summary
        rebuildOverlaysAndRegion()
    }

    // MARK: - Derived display texts
    var areaText: String { "\(Int(summary.capturedArea))" }
    var durationText: String {
        let seconds = Int(summary.duration)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
    var distanceText: String { String(format: "%.2f", summary.distance / 1000) }
    var caloriesText: String { "\(Int(summary.calories))" }
    var dateText: String { summary.startTime.formattedYMD() }
    var timeWeekdayText: String {
        let s = summary.startTime
        return "\(s.formattedHM()) (\(s.koreanWeekday()))"
    }
    
    private func rebuildOverlaysAndRegion() {
        self.overlays = MapOverlayBuilder.makeOverlays(coordinates: summary.coordinates, areas: summary.capturedAreas)
        if let region = MapOverlayBuilder.makeRegionToFit(coordinates: summary.coordinates) {
            self.region = region
        }
    }
}
