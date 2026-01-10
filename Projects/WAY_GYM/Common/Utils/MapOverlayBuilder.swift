//
//  MapOverlayBuilder.swift
//  WAY_GYM
//
//  Created by 이주현 on 8/12/25.
//
import Foundation
import MapKit
import CoreLocation

// MARK: - 지도 오버레이 생성
enum MapOverlayBuilder {
    
    // polylines + polygons를 한 번에 생성
    static func makeOverlays(coordinates: [CoordinatePair], areas: [CoordinatePairWithGroup]) -> [MKOverlay] {
        let polys = makePolygons(from: areas)
        let lines = makePolylines(from: coordinates)
        return polys + lines
    }
    
    // 좌표 배열로 지도를 보기 좋게 맞추는 region 계산
    static func makeRegionToFit(coordinates: [CoordinatePair], minimumSpan: CLLocationDegrees = 0.003, paddingFactor: Double = 0.5) -> MKCoordinateRegion? {
        let coords = coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard coords.count >= 2 else { return nil }
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * paddingFactor, minimumSpan)
        let spanLon = max((maxLon - minLon) * paddingFactor, minimumSpan)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }

    static func makePolylines(from coordinates: [CoordinatePair]) -> [MKPolyline] {
        guard coordinates.count >= 2 else { return [] }

        let locationCoords = coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = MKPolyline(coordinates: locationCoords, count: locationCoords.count)
        return [polyline]
    }

    static func makePolygons(from areas: [CoordinatePairWithGroup]) -> [MKPolygon] {
        let grouped = Dictionary(grouping: areas, by: { $0.groupId })

        return grouped.values.compactMap { group in
            let coords = group.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            return MKPolygon(coordinates: coords, count: coords.count)
        }
    }
}
