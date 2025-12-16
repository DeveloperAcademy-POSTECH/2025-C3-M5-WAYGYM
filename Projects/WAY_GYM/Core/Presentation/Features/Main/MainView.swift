import SwiftUI
import MapKit
import CoreLocation
import HealthKit
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Photos
import FirebaseCore

struct MainView: View {
    @ObservedObject var locationManager: LocationManager
    @EnvironmentObject var router: AppRouter
    
    @State private var showResult = false
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    
    @State private var isCountingDown = false
    @State private var countdown = 3
    
    @StateObject private var runRecordService = RunRecordService()
    @State private var showResultModal = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MapView(
                region: $locationManager.region,
                polylines: locationManager.polylines,
                polygons: locationManager.polygons,
                currentLocation: $locationManager.currentLocation,
                selectedWeaponId: selectedWeaponId
            )
            .edgesIgnoringSafeArea(.all)
            
            // 내 나와바리 이동 버튼
            if !locationManager.isSimulating {
                HStack{
                    VStack(spacing: 6) {
                        NavigationLink(destination:
                            ProfileView()
                                .environmentObject(AppRouter())
                                .environmentObject(RunRecordService())
                                .font(.text01)
                                .foregroundColor(Color.gang_text_2)
                        ) {
                            Image("ProfilIcon")
                                .resizable()
                                .frame(width: 40, height: 40)
                        }
                        Text("내 나와바리")
                            .font(.text02)
                            .foregroundColor(.white)
                        // .padding(20)
                        Spacer()
                        
                    }
                    Spacer()
                }
                .padding(20)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                VStack {
                    ControlPanelView(
                        locationManager: locationManager,
                        isSimulating: $locationManager.isSimulating,
                        startAction: locationManager.startSimulation,
                        stopAction: locationManager.stopSimulation,
                        moveToCurrentLocationAction: locationManager.moveToCurrentLocation,
                        loadCapturedPolygons: { locationManager.loadCapturedPolygons(from: locationManager.runRecordList) },
                        isCountingDown: $isCountingDown,
                        countdown: $countdown,
                        showResultModal: $showResultModal,
                        isAreaActive: $locationManager.isAreaActive
                    )
                    Spacer()
                }
            }
            
            if isCountingDown {
                Color.gang_start_bg
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        Text("\(countdown)")
                            .font(.countdown)
                            .foregroundColor(Color.gang_highlight_2)
                    )
                    .transition(.opacity)
            }
        }
        .onAppear {
            locationManager.fetchRunRecordsFromFirestore()
            locationManager.moveToCurrentLocation()
            
            locationManager.isSimulating = false
            isCountingDown = false
            countdown = 3
        }
        .overlay {
            if showResultModal {
                ZStack {
                    Color.gang_black_opacity
                        .ignoresSafeArea()
                    
                    RunResultModalView(onComplete: { showResultModal = false })
                        .environmentObject(runRecordService)
                        .environmentObject(router)
                }
            }
        }
    }
}

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
        
        // print("Rendering valid polylines: \(validPolylines.count) / \(polylines.count)")
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

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.showsPointsOfInterest = false
        
        if !coordinates.isEmpty {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            let region = coordinateRegionForCoordinates(coordinates)
            mapView.setRegion(region, animated: true)
        }
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func coordinateRegionForCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let maxLat = latitudes.max()!
        let minLat = latitudes.min()!
        let maxLon = longitudes.max()!
        let minLon = longitudes.min()!
        
        let center = CLLocationCoordinate2D(
            latitude: (maxLat + minLat) / 2,
            longitude: (maxLon + minLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemGreen
                renderer.lineWidth = 2
                return renderer
            }
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.yellow.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.yellow
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

