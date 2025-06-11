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
                        NavigationLink(destination: ProfileView()
                            .environmentObject(MinionViewModel())
                            .environmentObject(WeaponViewModel())
                            .environmentObject(AppRouter())
                            .environmentObject(RunRecordViewModel())
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
                    ControlPanel(
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
        .sheet(isPresented: $showResult) {
            ResultView(locationManager: locationManager, showResult: $showResult)
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
                        .environmentObject(runRecordVM)
                        .environmentObject(weaponVM)
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
        print("Rendering polylines: \(polylines.count)")
        polylines.forEach { mapView.addOverlay($0) }
        
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

struct ControlPanel: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var isSimulating: Bool
    let startAction: () -> Void
    let stopAction: () -> Void
    let moveToCurrentLocationAction: () -> Void
    let loadCapturedPolygons: () -> Void
    @Binding var isCountingDown: Bool
    @Binding var countdown: Int
    @Binding var showResultModal: Bool
    @Binding var isAreaActive: Bool
    
    @State private var isLocationActive = false
    @State private var isHolding: Bool = false
    @State private var holdProgress: CGFloat = 0.0
    @State private var showTipBox: Bool = false
    @State private var backupPolylines: [MKPolyline] = []
    
    var body: some View {
        ZStack {
            if showTipBox {
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
                        .font(.title02)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 36)
                }
                .padding(.horizontal, 34)
                .padding(.top, 20)
                .position(x: UIScreen.main.bounds.width / 2, y: 120)
                .ignoresSafeArea()
                .zIndex(1)
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    if !isSimulating {
                        VStack(spacing: 25) {
                            VStack(spacing: 12) {
                                Button(
                                    action: {
                                        moveToCurrentLocationAction()
                                        isLocationActive.toggle()
                                    }) {
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
                            
                            VStack(spacing: 12) {
                                Button(
                                    action: {
                                        isAreaActive.toggle()
                                        if isAreaActive {
                                            backupPolylines = locationManager.polylines
                                            locationManager.polylines.removeAll()
                                            loadCapturedPolygons()
                                            print("Polylines cleared: \(locationManager.polylines.isEmpty)")
                                            // Firestore 리스너 재호출로 polylines 방지
                                            locationManager.fetchRunRecordsFromFirestore()
                                        } else {
                                            locationManager.polygons.removeAll()
                                            locationManager.polylines = backupPolylines
                                            print("Polylines restored: \(locationManager.polylines.count)")
                                            locationManager.fetchRunRecordsFromFirestore()
                                        }
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
                                Text("차지한\n영역")
                                    .multilineTextAlignment(.center)
                                    .font(.text02)
                                    .foregroundColor(isAreaActive ? .yellow : .white)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    if isSimulating {
                        VStack {
                            Button(
                                action: {
                                    moveToCurrentLocationAction()
                                    isLocationActive.toggle()
                                }) {
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
                        .padding(.trailing, 16)
                    }
                }
                
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if !isSimulating && !isCountingDown {
                            isCountingDown = true
                            countdown = 3
                            startCountdown()
                            print("재생 버튼 눌림")
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
                                            if isSimulating && !isHolding {
                                                isHolding = true
                                                showTipBox = true
                                                startFilling()
                                            }
                                        }
                                        .onEnded { _ in
                                            isHolding = false
                                            holdProgress = 0.0
                                            showTipBox = false
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
//                    .onTapGesture {
//                        if !isSimulating && !isCountingDown {
//                            startCountdown()
//                        }
//                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    func startCountdown() {
        guard !isSimulating else {
            print("⛔️ 이미 시뮬레이션 중이므로 countdown 시작 안 함")
            return
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown == 0 {
                timer.invalidate()
                isCountingDown = false
                isSimulating = true
                startAction()

                print("✅ startCountdown 실행됨") 

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
                    showTipBox = false
                    stopAction()

                    isCountingDown = false
                    countdown = 3
                    showResultModal = true
                    runRecordVM.resetDistanceCache()
                }
            } else {
                timer.invalidate()
                holdProgress = 0.0
            }
        }
    }
}
