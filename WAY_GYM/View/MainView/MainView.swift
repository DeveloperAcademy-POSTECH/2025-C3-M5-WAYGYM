import SwiftUI
import MapKit
import CoreLocation
import HealthKit
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Photos
import FirebaseCore // Firebase 초기화를 위해 추가

// MARK: - 메인 뷰
struct MainView: View {
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var router: AppRouter // 외부 종속성, 필요 시 활성화
    @State private var showResult = false
    @AppStorage("selectedWeaponId") var selectedWeaponId: String = "0"
    
    @State private var isCountingDown = false
    @State private var countdown = 3
    
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
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        router.currentScreen = .profile // AppRouter 필요 시 활성화
                        print("Profile button tapped")
                    }) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                    }
                    .padding(20)
                }
                Spacer()
                Text(String(format: "이동 거리: %.3f m", locationManager.isSimulating ? locationManager.calculateTotalDistance() : 0.0))
                    .font(.system(size: 16, weight: .bold))
                    .padding(10)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 80)
                
                ControlPanel(
                    isSimulating: $locationManager.isSimulating,
                    showResult: $showResult,
                    startAction: locationManager.startSimulation,
                    stopAction: locationManager.stopSimulation,
                    moveToCurrentLocationAction: locationManager.moveToCurrentLocation,
                    isCountingDown: $isCountingDown,
                    countdown: $countdown
                )
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
        .sheet(isPresented: $showResult) {
            ResultView(locationManager: locationManager, showResult: $showResult)
        }
        .onAppear {
             // FirebaseApp.configure() // Firebase 초기화
            // locationManager.requestHealthKitAuthorization()
            locationManager.fetchRunRecordsFromFirestore()
            locationManager.moveToCurrentLocation()
//            locationManager.setupSimulatorLocation() // 시뮬레이터 초기화
        }
    }
}

// MARK: - 지도 뷰
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
        // mapView.isOpaque = true // 렌더링 최적화
        // mapView.isMultipleTouchEnabled = false // 불필요한 터치 이벤트 방지
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        mapView.removeOverlays(mapView.overlays)
        polylines.forEach { mapView.addOverlay($0) }
        polygons.forEach { mapView.addOverlay($0) }
        
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
                renderer.lineWidth = 3
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(Color.green).withAlphaComponent(0.5)
                renderer.strokeColor = UIColor(Color.green)
                renderer.lineWidth = 4
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

// MARK: - 경로 지도 표시 뷰
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
    
    func updateUIView(_ mapView: MKMapView, context _: Context) {}
    
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
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

// MARK: - 컨트롤 패널
struct ControlPanel: View {
    @Binding var isSimulating: Bool
    @Binding var showResult: Bool
    let startAction: () -> Void
    let stopAction: () -> Void
    let moveToCurrentLocationAction: () -> Void
    
    @Binding var isCountingDown: Bool
    @Binding var countdown: Int
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Button(action: {
                    if !isSimulating {
                        isCountingDown = true
                        countdown = 3
                        startCountdown()
                    }
                    else {
                        toggleSimulation()
                    }
                }) {
                    Text(isSimulating ? "정지" : "시작")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 80, height: 40)
                        .background(isSimulating ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
            }
            
            Button(action: { showResult = true }) {
                Text("결과보기")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 100, height: 40)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 3)
            }
            
            Button(action: moveToCurrentLocationAction) {
                Text("현재 위치")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 100, height: 40)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 3)
            }
        }
        .padding(.bottom, 30)
    }
    
    func toggleSimulation() {
        isSimulating ? stopAction() : startAction()
    }
    
    
    func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown == 0 {
                timer.invalidate()
                isCountingDown = false
                toggleSimulation()
            }
        }
    }
}

// MARK: - 프리뷰
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AppRouter()) // AppRouter 필요 시 활성화
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

struct RView_Previews: PreviewProvider {
    static var previews: some View {
        // RootView() // RootView 정의 필요 시 활성화
        MainView()
    }
}
