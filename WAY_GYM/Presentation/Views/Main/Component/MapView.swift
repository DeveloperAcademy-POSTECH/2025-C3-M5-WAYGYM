//
//  MapView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/9/26.
//

import SwiftUI
import MapKit

// LocationManager가 만든 상태(region/overlays/currentLocation)를 받아서 “그리기만 하는” 렌더러
struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var polylines: [MKPolyline]
    var polygons: [MKPolygon]
    @Binding var currentLocation: CLLocationCoordinate2D?
    let selectedWeaponId: String
    var shouldRenderPolylines: Bool = false
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isProgrammaticRegionChange = true
        mapView.setRegion(region, animated: true)
        DispatchQueue.main.async {
            context.coordinator.isProgrammaticRegionChange = false
        }

        mapView.removeOverlays(mapView.overlays)
        polygons.forEach { mapView.addOverlay($0) }

        if shouldRenderPolylines {
            // 유효한 폴리라인만 그리기
            let validPolylines = polylines.filter { polyline in
                let points = polyline.points()
                let count = polyline.pointCount

                // 폴리라인의 모든 좌표가 유효한지 확인
                for i in 0..<count {
                    let coordinate = points[i].coordinate
                    if coordinate.latitude < -90 || coordinate.latitude > 90 ||
                       coordinate.longitude < -180 || coordinate.longitude > 180 {
                        return false
                    }
                }
                return true
            }
            print("Rendering valid polylines: \(validPolylines.count) / \(polylines.count)")
            validPolylines.forEach { mapView.addOverlay($0) }
        }

        if let currentLocation = currentLocation {
            if let annotation = context.coordinator.currentLocationAnnotation {
                if annotation.coordinate.latitude != currentLocation.latitude ||
                    annotation.coordinate.longitude != currentLocation.longitude {
                    annotation.coordinate = currentLocation
                }
            } else {
                let annotation = MKPointAnnotation()
                annotation.coordinate = currentLocation
                annotation.title = "현재 위치"
                context.coordinator.currentLocationAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
        } else if let annotation = context.coordinator.currentLocationAnnotation {
            mapView.removeAnnotation(annotation)
            context.coordinator.currentLocationAnnotation = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var isProgrammaticRegionChange: Bool = false
        var currentLocationAnnotation: MKPointAnnotation?
        
        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // User-driven pan/zoom should update the SwiftUI binding.
            guard !isProgrammaticRegionChange else { return }

            let newRegion = mapView.region
            DispatchQueue.main.async {
                self.parent.region = newRegion
            }
        }
        
        // 차지한 땅 색칠
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.green)
                renderer.lineWidth = 2
                
                return renderer
            }

            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let isMine = (polygon as? ColoredPolygon)?.isMine ?? true
                let fillColor = isMine ? UIColor(Color.green) : UIColor(Color.red)
                renderer.fillColor = fillColor.withAlphaComponent(0.5)
                renderer.strokeColor = fillColor
                renderer.lineWidth = 2
                return renderer
            }

            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "CurrentLocation"
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            annotationView.annotation = annotation

            let imageName = "main_\(parent.selectedWeaponId)"
            let resolvedImage = UIImage(named: imageName) ?? UIImage(named: "H")
            annotationView.image = resolvedImage

            if UIImage(named: imageName) == nil {
                print("이미지 로드 실패: \(imageName)")
            }

            let imageSize = CGSize(width: 80, height: 80)
            annotationView.frame = CGRect(origin: .zero, size: imageSize)
            annotationView.centerOffset = CGPoint(x: 0, y: -imageSize.height / 2)
            annotationView.canShowCallout = true

            return annotationView
        }
    }
}
