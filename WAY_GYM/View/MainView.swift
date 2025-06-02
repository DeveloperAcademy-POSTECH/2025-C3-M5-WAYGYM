//
//  MainView.swift
//  WAY_GYM
//
//  Created by Leo on 5/27/25.
//
import SwiftUI
import MapKit
import CoreLocation
import HealthKit

// MARK: - 메인 뷰
struct MainView: View {
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var router: AppRouter
    @State private var showResult = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MapView(
                region: $locationManager.region,
                polylines: locationManager.polylines,
                polygons: locationManager.polygons,
                currentLocation: $locationManager.currentLocation
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack{
                    Spacer()
                    Button(action: {
                        router.currentScreen = .profile
                    }) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                    }
                    .padding(20)
                }
                Spacer()
                Text(String(format: "이동 거리: %.3f m", locationManager.calculateTotalDistance()))
                    .font(.system(size: 16, weight: .bold))
                    .padding(10)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                ControlPanel(
                    isSimulating: $locationManager.isSimulating,
                    showResult: $showResult,
                    startAction: locationManager.startSimulation,
                    stopAction: locationManager.stopSimulation,
                    moveToCurrentLocationAction: locationManager.moveToCurrentLocation
                )
            }
        }
//        .sheet(isPresented: $showResult) {
//            ResultView(locationManager: locationManager, showResult: $showResult)
//        }
        .onAppear {
            locationManager.requestHealthKitAuthorization()
        }
    
    }
}

// MARK: - 위치 관리 클래스
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion()
    @Published var polylines: [MKPolyline] = []
    @Published var polygons: [MKPolygon] = []
    @Published var isSimulating = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var stepCount: Double = 0
    @Published var caloriesBurned: Double = 0
    
    private let clManager = CLLocationManager()
    private var coordinates: [CLLocationCoordinate2D] = []
    private var simulationTimer: Timer?
    private var lastIntersectionIndex: Int?
    private let healthStore = HKHealthStore()
    
    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.requestWhenInUseAuthorization()
    }
    
    // HealthKit 권한 요청
    func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.fetchHealthData()
            } else if let error = error {
                print("HealthKit 권한 요청 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // HealthKit 데이터 가져오기 (걸음 수 및 칼로리)
    func fetchHealthData() {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -1, to: now) else { return }
        
        // 걸음 수 쿼리
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, error in
                if let result = result, let sum = result.sumQuantity() {
                    DispatchQueue.main.async {
                        self.stepCount = sum.doubleValue(for: HKUnit.count())
                    }
                } else if let error = error {
                    print("걸음 수 데이터 가져오기 실패: \(error.localizedDescription)")
                }
            }
            healthStore.execute(query)
        }
        
        // 칼로리 쿼리
        if let calorieType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: calorieType,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, error in
                if let result = result, let sum = result.sumQuantity() {
                    DispatchQueue.main.async {
                        self.caloriesBurned = sum.doubleValue(for: HKUnit.kilocalorie())
                    }
                } else if let error = error {
                    print("칼로리 데이터 가져오기 실패: \(error.localizedDescription)")
                }
            }
            healthStore.execute(query)
        }
    }
    
    // CLLocationManagerDelegate: 위치 권한 변경 처리
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            clManager.startUpdatingLocation()
        }
    }
    
    // CLLocationManagerDelegate: 위치 업데이트 처리
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let newCoordinate = location.coordinate
        currentLocation = newCoordinate
        if isSimulating {
            updateCoordinates(newCoordinate: newCoordinate)
        }
        updateRegion(coordinate: newCoordinate)
    }
    
    // 시뮬레이션 시작
    func startSimulation() {
        guard clManager.authorizationStatus == .authorizedWhenInUse || clManager.authorizationStatus == .authorizedAlways else {
            clManager.requestWhenInUseAuthorization()
            return
        }
        
        isSimulating = true
        coordinates.removeAll()
        polylines.removeAll()
        polygons.removeAll()
        lastIntersectionIndex = nil
        
        clManager.startUpdatingLocation()
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let lastLocation = self.clManager.location {
                if self.isSimulating {
                    self.updateCoordinates(newCoordinate: lastLocation.coordinate)
                }
                self.currentLocation = lastLocation.coordinate
                self.updateRegion(coordinate: lastLocation.coordinate)
            }
        }
    }
    
    // 시뮬레이션 정지
    func stopSimulation() {
        isSimulating = false
        simulationTimer?.invalidate()
        clManager.stopUpdatingLocation()
    }
    
    // 현재 위치로 지도 이동
    func moveToCurrentLocation() {
        guard clManager.authorizationStatus == .authorizedWhenInUse || clManager.authorizationStatus == .authorizedAlways else {
            clManager.requestWhenInUseAuthorization()
            return
        }
        
        if let currentLocation = clManager.location {
            updateRegion(coordinate: currentLocation.coordinate)
            self.currentLocation = currentLocation.coordinate
        } else {
            clManager.startUpdatingLocation()
        }
    }
    
    // 좌표 업데이트
    private func updateCoordinates(newCoordinate: CLLocationCoordinate2D) {
        coordinates.append(newCoordinate)
        updateMapOverlays()
        checkForPolygon()
        updateRegion(coordinate: newCoordinate)
    }
    
    // 지도 오버레이 갱신
    private func updateMapOverlays() {
        let startIdx = (lastIntersectionIndex ?? -1) + 1
        guard startIdx + 1 < coordinates.count else { return }
        
        let recentCoordinates = Array(coordinates[startIdx...])
        let polyline = MKPolyline(coordinates: recentCoordinates, count: recentCoordinates.count)
        polylines.append(polyline)
    }
    
    // 영역 자동 조정
    private func updateRegion(coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }
    
    // 교차점 감지
    private func checkForPolygon() {
        guard coordinates.count >= 4 else { return }

        let newLineStart = coordinates[coordinates.count - 2]
        let newLineEnd = coordinates[coordinates.count - 1]

        for i in 0..<coordinates.count - 3 {
            let existingLineStart = coordinates[i]
            let existingLineEnd = coordinates[i + 1]

            if linesIntersect(
                line1Start: existingLineStart,
                line1End: existingLineEnd,
                line2Start: newLineStart,
                line2End: newLineEnd
            ) {
                if let x = intersectionPoint(
                    line1Start: existingLineStart,
                    line1End: existingLineEnd,
                    line2Start: newLineStart,
                    line2End: newLineEnd
                ) {
                    let polygonCoordinates: [CLLocationCoordinate2D] =
                        [x] + coordinates[(i+1)...(coordinates.count - 2)] + [x]
                    let polygon = MKPolygon(coordinates: polygonCoordinates, count: polygonCoordinates.count)
                    polygons.append(polygon)

                    lastIntersectionIndex = coordinates.count - 2
                }
                break
            }
        }
    }
    
    // 교차점 계산
    private func intersectionPoint(
        line1Start: CLLocationCoordinate2D,
        line1End: CLLocationCoordinate2D,
        line2Start: CLLocationCoordinate2D,
        line2End: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D? {
        let x1 = line1Start.longitude
        let y1 = line1Start.latitude
        let x2 = line1End.longitude
        let y2 = line1End.latitude
        let x3 = line2Start.longitude
        let y3 = line2Start.latitude
        let x4 = line2End.longitude
        let y4 = line2End.latitude

        let denominator = (x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4)
        if denominator == 0 { return nil }

        let px = ((x1*y2 - y1*x2)*(x3 - x4) - (x1 - x2)*(x3*y4 - y3*x4)) / denominator
        let py = ((x1*y2 - y1*x2)*(y3 - y4) - (y1 - y2)*(x3*y4 - y3*x4)) / denominator

        return CLLocationCoordinate2D(latitude: py, longitude: px)
    }
    
    // 교차점 감지
    private func linesIntersect(
        line1Start: CLLocationCoordinate2D,
        line1End: CLLocationCoordinate2D,
        line2Start: CLLocationCoordinate2D,
        line2End: CLLocationCoordinate2D
    ) -> Bool {
        let p1 = CGPoint(x: line1Start.longitude, y: line1Start.latitude)
        let p2 = CGPoint(x: line1End.longitude, y: line1End.latitude)
        let p3 = CGPoint(x: line2Start.longitude, y: line2Start.latitude)
        let p4 = CGPoint(x: line2End.longitude, y: line2End.latitude)
        
        let denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
        if denominator == 0 { return false }
        
        let ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
        let ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denominator
        
        return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1
    }
    
    // 총 이동 거리 계산 (미터)
    func calculateTotalDistance() -> Double {
        guard coordinates.count >= 2 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        for i in 0..<coordinates.count - 1 {
            let start = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let end = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            totalDistance += start.distance(from: end)
        }
        return totalDistance
    }
}

// MARK: - 지도 뷰
struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var polylines: [MKPolyline]
    var polygons: [MKPolygon]
    @Binding var currentLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView() 
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        let currentOverlays = mapView.overlays
        mapView.removeOverlays(currentOverlays)
        
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
                renderer.strokeColor = .systemGreen // 경로 선을 연두색으로 설정
                renderer.lineWidth = 3
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.green.withAlphaComponent(0.5) // 폴리곤 채우기를 초록색으로 설정
                renderer.strokeColor = .green // 폴리곤 테두리를 초록색으로 설정
                renderer.lineWidth = 4
                return renderer
            }
            
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "CurrentLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            //좌표가 튀는지 확인해보기(계속 생성 하는지 포지셔만 옮겨지는지 알아보기
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                // Assets에 있는 Image 이미지 사용
                annotationView?.image = UIImage(named: "Image")
                // 이미지 크기를 2배로 조정 (60x60)
                let imageSize = CGSize(width: 60, height: 60)
                annotationView?.frame = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
                // 이미지 중심을 핀의 하단 중앙으로 설정
                annotationView?.centerOffset = CGPoint(x: 0, y: -imageSize.height / 2)
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.canShowCallout = true
            return annotationView
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
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: toggleSimulation) {
                Text(isSimulating ? "정지" : "시작")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 80, height: 40)
                    .background(isSimulating ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 3)
            }
            
//            Button(action: { showResult = true }) {
//                Text("결과보기")
//                    .font(.system(size: 18, weight: .bold))
//                    .frame(width: 100, height: 40)
//                    .background(Color.green)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                    .shadow(radius: 3)
//            }
//            
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
    
    private func toggleSimulation() {
        isSimulating ? stopAction() : startAction()
    }
}

// MARK: - 결과 뷰 (모달)
//struct ResultView: View {
//    @ObservedObject var locationManager: LocationManager
//    @Binding var showResult: Bool
//    
//    var body: some View {
//        VStack {
//            Text(String(format: "총 이동 거리: %.3f m", locationManager.calculateTotalDistance()))
//                .font(.title2)
//                .padding(.bottom)
//            
//            Text(String(format: "걸음 수: %.0f 걸음", locationManager.stepCount))
//                .font(.title2)
//                .padding(.bottom)
//            
//            Text(String(format: "소모 칼로리: %.0f kcal", locationManager.caloriesBurned))
//                .font(.title2)
//                .padding(.bottom)
//            
//            Button(action: { showResult = false }) {
//                Text("닫기")
//                    .font(.system(size: 18, weight: .bold))
//                    .frame(width: 100, height: 40)
//                    .background(Color.gray)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                    .shadow(radius: 3)
//            }
//            .padding(.top, 10)
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 10)
//    }
//}

// MARK: - 프리뷰
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AppRouter())
    }
}

