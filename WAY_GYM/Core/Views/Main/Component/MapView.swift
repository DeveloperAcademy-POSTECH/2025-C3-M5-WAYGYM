//
//  MapView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/9/26.
//

import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var polylines: [MKPolyline]
    var polygons: [MKPolygon]
    @Binding var currentLocation: CLLocationCoordinate2D?
    let selectedWeaponId: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.showsPointsOfInterest = false
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        mapView.removeOverlays(mapView.overlays)
        polygons.forEach { mapView.addOverlay($0) }
        
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
        
        mapView.removeAnnotations(mapView.annotations)
        if let currentLocation = currentLocation {
            let annotation = MKPointAnnotation()
            annotation.coordinate = currentLocation
            annotation.title = "현재 위치"
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.green)
                renderer.lineWidth = 2
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(Color.green).withAlphaComponent(0.5)
                renderer.strokeColor = UIColor(Color.green)
                renderer.lineWidth = 2
                return renderer
            }
            
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "CurrentLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                let imageName = "main_\(parent.selectedWeaponId)"
                annotationView?.image = UIImage(named: imageName) ?? UIImage(named: "H")
                if UIImage(named: imageName) == nil {
                    print("이미지 로드 실패: \(imageName)")
                }
                let imageSize = CGSize(width: 80, height: 80)
                annotationView?.frame = CGRect(origin: .zero, size: imageSize)
                annotationView?.centerOffset = CGPoint(x: 0, y: -imageSize.height / 2)
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.canShowCallout = true
            return annotationView
        }
    }
}
