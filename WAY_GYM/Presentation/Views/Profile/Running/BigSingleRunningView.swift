//
//  BigSingleRunningView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/4/25.
//

import SwiftUI
import MapKit

struct BigSingleRunningView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject private var runRecordStore: RunRecordStore

    private let runId: String?
    private let initialSummary: RunRecord?

    init(runId: String) {
        self.runId = runId
        self.initialSummary = nil
    }

    init(summary: RunRecord) {
        self.runId = nil
        self.initialSummary = summary
    }

    private var resolvedSummary: RunRecord? {
        if let initialSummary { return initialSummary }
        guard let runId else { return nil }
        return runRecordStore.runRecords.first(where: { $0.id == runId })
    }

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @State private var overlays: [MKOverlay] = []
    @State private var polygons: [MKPolygon] = []

    var body: some View {
        Group {
            if let summary = resolvedSummary {
                ZStack {
                    RunHistoryMapView(
                        polylines: overlays as! [MKPolyline],
                        polygons: polygons,
                        region: region
                    )
                    .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        VStack {
                            HStack {
                                customLabel(value: "TODO", title: "영역(m²)")
                                
                                Spacer()
                                
                                VStack() {
                                    Text(summary.startTime.formattedYMD())
                                    Text("\(summary.startTime.formattedHM()) (\(summary.startTime.koreanWeekday()))")
                                }
                                .font(.text01)
                                .padding(.trailing, 16)
                            }
                            
                            Spacer()
                                .frame(height: 24)
                            
                            HStack {
                                customLabel(value: "\(Int(summary.duration) / 60):\(String(format: "%02d", Int(summary.duration) % 60))", title: "소요시간")
                                Spacer()
                                customLabel(value: String(format: "%.2f", summary.distanceM / 1000), title: "거리(km)")
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .frame(width: UIScreen.main.bounds.width)
                        .frame(height: UIScreen.main.bounds.height * 0.21)
                        .background(Color.gang_sheet_bg_opacity)
                        .cornerRadius(16)
                        
                    }
                    .ignoresSafeArea()
                    
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button {
                                coordinator.pop()
                            } label: {
                                Image("xmark")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color.gang_text_2)
                                    .padding(15)
                                    .background(Circle().foregroundStyle(Color.gang_bg))
                            }
                        }
                        .padding(.horizontal, 16)
                        Spacer()
                    }
                }
                .task(id: summary.id) {
                    configureMap(for: summary)
                }
                .navigationBarBackButtonHidden(true)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("러닝 기록을 불러오는 중입니다...")
                        .font(.text01)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
    }

    // MARK: - Map configuration
    private func configureMap(for summary: RunRecord) {
        // 1) routeEncoded → 좌표 디코딩
        let coords = decodePolyline(summary.routeEncoded)

        // 2) 폴리라인 오버레이
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        self.overlays = [polyline]

        // 3) routeFrame 기반으로 지도 영역 설정 (썸네일과 동일한 프레이밍)
        if summary.routeFrame.count == 4 {
            let minLat = summary.routeFrame[0]
            let minLon = summary.routeFrame[1]
            let maxLat = summary.routeFrame[2]
            let maxLon = summary.routeFrame[3]

            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2

            let spanLat = max((maxLat - minLat) * 1.2, 0.003)
            let spanLon = max((maxLon - minLon) * 1.2, 0.003)

            self.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )
        }
        // 4) capturedCellIds → polygon overlays
        let gridSize = 0.0005
        self.polygons = summary.capturedCellIds.compactMap { id in
            let parts = id.split(separator: ",")
            guard parts.count == 2,
                  let lat = Double(parts[0]),
                  let lng = Double(parts[1]) else { return nil }

            let minLat = lat
            let minLng = lng
            let maxLat = lat + gridSize
            let maxLng = lng + gridSize

            let coords: [CLLocationCoordinate2D] = [
                .init(latitude: minLat, longitude: minLng),
                .init(latitude: minLat, longitude: maxLng),
                .init(latitude: maxLat, longitude: maxLng),
                .init(latitude: maxLat, longitude: minLng),
                .init(latitude: minLat, longitude: minLng)
            ]

            return MKPolygon(coordinates: coords, count: coords.count)
        }
    }
    
    
    // MARK: - Encoded polyline decode
    private func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        guard !encoded.isEmpty else { return [] }

        var coords: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex

        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            var b: Int
            var shift = 0
            var result = 0

            repeat {
                b = Int(encoded[index].asciiValue!) - 63
                index = encoded.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1)
            lat += dlat

            shift = 0
            result = 0

            repeat {
                b = Int(encoded[index].asciiValue!) - 63
                index = encoded.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1)
            lng += dlng

            coords.append(
                CLLocationCoordinate2D(
                    latitude: Double(lat) / 1e5,
                    longitude: Double(lng) / 1e5
                )
            )
        }

        return coords
    }
    // TODO: - 지도 오버레이 생성 (임시: 나중에 별도 ViewModel로 이동)
    private func makePolylines(from coordinates: [CoordinatePair]) -> [MKPolyline] {
        guard coordinates.count >= 2 else { return [] }

        let locationCoords = coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = MKPolyline(coordinates: locationCoords, count: locationCoords.count)
        return [polyline]
    }

    private func makePolygons(from areas: [CoordinatePairWithGroup]) -> [MKPolygon] {
        let grouped = Dictionary(grouping: areas, by: { $0.groupId })

        return grouped.values.compactMap { group in
            let coords = group.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            return MKPolygon(coordinates: coords, count: coords.count)
        }
    }
    
    // MARK: View 조각들
    struct customLabel: View {
        let value: String
        let title: String
        
        var body: some View {
            VStack {
                Text(value)
                    .font(.title01)
                Text(title)
                    .font(.title03)
            }
            .padding(.horizontal, 16)
        }
    }
    
    struct RunHistoryMapView: UIViewRepresentable {
        let polylines: [MKPolyline]
        let polygons: [MKPolygon]
        let region: MKCoordinateRegion

        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.delegate = context.coordinator
            mapView.isUserInteractionEnabled = true
            mapView.setRegion(region, animated: false)
            mapView.pointOfInterestFilter = .excludingAll
            mapView.mapType = .mutedStandard
            mapView.overrideUserInterfaceStyle = .dark
            return mapView
        }

        func updateUIView(_ uiView: MKMapView, context: Context) {
            uiView.setRegion(region, animated: false)
            uiView.removeOverlays(uiView.overlays)
            polygons.forEach { uiView.addOverlay($0) }
            polylines.forEach { uiView.addOverlay($0) }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator: NSObject, MKMapViewDelegate {
            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                if let polygon = overlay as? MKPolygon {
                    let renderer = MKPolygonRenderer(polygon: polygon)
                    renderer.fillColor = UIColor.gang_area
                    return renderer
                } else if let polyline = overlay as? MKPolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = UIColor.successColor
                    renderer.lineWidth = 3
                    return renderer
                }
                return MKOverlayRenderer()
            }
        }
    }
    
}
