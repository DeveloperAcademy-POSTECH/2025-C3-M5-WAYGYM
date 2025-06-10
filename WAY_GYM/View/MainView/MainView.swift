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
    
    @StateObject private var weaponVM = WeaponViewModel()
    @StateObject private var runRecordVM = RunRecordViewModel()
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
                            Button(action: {
                                router.currentScreen = .profile
                            }) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 46))
                                    .foregroundColor(.white)
                            }
                            Text("내 나와바리")
                                .font(.text02)
                                .foregroundColor(.white)
                            // .padding(20)
                            Spacer()
                        }
                        .padding(20)
                        Spacer()
                    }
                } // 내 나와바리 이동 버튼
            
            HStack{
                Spacer()
                VStack{
                    ControlPanel(
                        isSimulating: $locationManager.isSimulating,
                        // showResult: $showResult,
                        startAction: locationManager.startSimulation,
                        stopAction: locationManager.stopSimulation,
                        moveToCurrentLocationAction: locationManager.moveToCurrentLocation,
                        loadCapturedPolygons:
                            { locationManager.loadCapturedPolygons(from: locationManager.runRecordList ) },
                        isCountingDown: $isCountingDown,
                        countdown: $countdown,
                        showResultModal: $showResultModal
                    )
                    // .padding(.trailing, 16)
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
        .overlay(content: {
            if showResultModal {
                ZStack {
                    Color.gang_black_opacity
                        .ignoresSafeArea()
                    
                    RunResultModalView(onComplete: { showResultModal = false })
                        .environmentObject(runRecordVM)
                        .environmentObject(weaponVM)
                        .environmentObject(router)
                }
            }
        })
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
                    ("이미지 로드 실패: \(imageName)")
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
    @StateObject private var locationManager = LocationManager()
    
    @Binding var isSimulating: Bool
    // @Binding var showResult: Bool
    let startAction: () -> Void
    let stopAction: () -> Void
    let moveToCurrentLocationAction: () -> Void
    let loadCapturedPolygons: () -> Void

    @State private var isLocationActive = false
    @State private var isAreaActive = false
    
    @Binding var isCountingDown: Bool
        @Binding var countdown: Int

        @State private var isHolding: Bool = false
        @State private var holdProgress: CGFloat = 0.0
        @State private var showTipBox: Bool = false
    
    @Binding var showResultModal: Bool
    
    
    var body: some View {
        VStack {
            
            if showTipBox {
                VStack {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 350, height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.yellow, lineWidth: 2)
                            )
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.yellow)
                            .frame(width: 350 * holdProgress, height: 50)
                        
                        Text("길게 눌러서 땅따먹기 종료")
                            .foregroundColor(.white)
                            .font(
                                .custom(
                                    "NeoDunggeunmoPro-Regular",
                                    size: 20
                                )
                            )
                            .frame(height: 36)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity)
                .alignmentGuide(.top) { _ in 0 }
                .ignoresSafeArea()
                .zIndex(1)
            }
            
            HStack {
                Spacer()
                
                if !isSimulating {
                    VStack(spacing: 20) {
                        // MARK: 현위치 버튼
                        VStack{
                            Button(
                                action: {
                                    moveToCurrentLocationAction();
                                    isLocationActive.toggle()
                                })  {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isLocationActive ? Color.yellow : Color.black)
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: "location.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 26, height: 26)
                                                .foregroundColor(
                                                    isLocationActive ? .black : .yellow
                                                )
                                        )
                                }
                            Text("내 위치")
                                .font(.text02)
                                .foregroundColor(isLocationActive ? .yellow : .white)
                        }
                        
                        // MARK: 차지한 영역 (면적 레이어 토글 버튼)
                        VStack{
                            Button(
                                action: {
                                    if isAreaActive {
                                        locationManager.polygons.removeAll() // 영역 제거
                                    } else {
                                        locationManager.loadCapturedPolygons(from: locationManager.runRecordList)
                                    }
                                    isAreaActive.toggle()
                                }) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isAreaActive ? Color.yellow : Color.black)
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: "map.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 26, height: 26)
                                                .foregroundColor(
                                                    isAreaActive ? .black : .yellow
                                                )
                                        )
                                }
                            Text("차지한 영역")
                                .font(.text02)
                                .foregroundColor(isAreaActive ? .yellow : .white)
                        }
                    }
                    .padding(.trailing, 16)
                }
                
                
            }
            
        }
        
        Spacer()
        
        // 재생 버튼
        HStack {
            Spacer()
            
            Button(action: {
                if !isSimulating {
                    isCountingDown = true
                    countdown = 3
                    startCountdown()
                }
            }) {
                if isSimulating {
                    Circle()
                        .fill(isHolding ? Color.yellow : Color.white)
                        .frame(width: 86, height: 86)
                        .overlay(
                            Text("◼️")
                                .font(.system(size: 38))
                                .foregroundColor(.black)
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isHolding {
                                        isHolding = true
                                        showTipBox = true
                                        startFilling()
                                    }
                                }
                                .onEnded { _ in
                                    isHolding = false
                                    holdProgress = 0.0

                                    if holdProgress >= 1.0 {
                                        showResultModal = true
                                    } else {
                                        holdProgress = 0.0
                                    }
                                }
                        )
                } else {
                    Image("startButton")
                        .resizable()
                        .frame(width: 86, height: 86)
                }
            }
            
            Spacer()
        } // 재생 버튼
    }
    
    func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown == 0 {
                timer.invalidate()
                isCountingDown = false
                // toggleSimulation()
                isSimulating = true
                startAction()
            }
        }
    }
    
    func startFilling() {
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if isHolding {
                holdProgress += 0.03
                if holdProgress >= 1.0 {
                    timer.invalidate()
                    holdProgress = 1.0
                    
                    DispatchQueue.main.async {
                        // showResult = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // showReward = true
                        }
                    }
                    
                    showTipBox = false
                    stopAction()
                    locationManager.stopSimulation()
                    showResultModal = true
                }
            } else {
                timer.invalidate()
                holdProgress = 0.0
            }
        }
    }
    
}
//
//// MARK: - 프리뷰
//struct MainView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainView()
//            .environmentObject(AppRouter()) // AppRouter 필요 시 활성화
//    }
//}
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainView()
//    }
//}
//
//struct RView_Previews: PreviewProvider {
//    static var previews: some View {
//        // RootView() // RootView 정의 필요 시 활성화
//        MainView()
//    }
//}
