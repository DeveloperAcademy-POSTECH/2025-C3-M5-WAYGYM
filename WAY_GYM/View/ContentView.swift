import SwiftUI
import MapKit
import CoreLocation
import HealthKit
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Photos



// MARK: - 데이터 모델
struct RunRecordModels: Identifiable, Codable {
    @DocumentID var id: String? // Firestore 문서 ID
    let distance: Double // 이동 거리 (미터)
    let stepCount: Double // 걸음 수
    let caloriesBurned: Double // 소모 칼로리 (kcal)
    let startTime: Date // 시작 시간
    let endTime: Date? // 종료 시간 (선택적)
    let duration: Double // 진행 시간 (분)
    let imageURL: String? // Firebase Storage 이미지 URL (선택적)
    let coordinates: [[Double]] // 경로 좌표 [[latitude, longitude]]
    
    enum CodingKeys: String, CodingKey {
        case id
        case distance
        case stepCount = "step_count"
        case caloriesBurned = "calories_burned"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case imageURL = "image_url"
        case coordinates
    }
    
    // 좌표를 CLLocationCoordinate2D로 변환
    var coordinateList: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }
}

// MARK: - 메인 뷰
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var showResult = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MapView(
                region: $locationManager.region,
                polylines: locationManager.polylines,
                polygons: locationManager.polygons,
                currentLocation: $locationManager.currentLocation,
                onPolygonAdded: locationManager.captureMapSnapshot
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Text(String(format: "이동 거리: %.3f m", locationManager.runRecord?.distance ?? 0))
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
                    moveToCurrentLocationAction: locationManager.moveToCurrentLocation
                )
            }
        }
        .sheet(isPresented: $showResult) {
            ResultView(locationManager: locationManager, showResult: $showResult)
        }
        .onAppear {
            locationManager.requestHealthKitAuthorization()
            locationManager.fetchRunRecordsFromFirestore()
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
    @Published var runRecord: RunRecordModels?
    @Published var runRecordList: [RunRecordModels] = []
    
    private let clManager = CLLocationManager()
    private var coordinates: [CLLocationCoordinate2D] = []
    private var simulationTimer: Timer?
    private var lastIntersectionIndex: Int?
    private var startTime: Date?
    private let healthStore = HKHealthStore()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private weak var mapView: MKMapView?
    
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
    
    // HealthKit 데이터 가져오기
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
                        let stepCount = sum.doubleValue(for: HKUnit.count())
                        self.updateRunRecord(stepCount: stepCount, calories: self.runRecord?.caloriesBurned ?? 0)
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
                        let calories = sum.doubleValue(for: HKUnit.kilocalorie())
                        self.updateRunRecord(stepCount: self.runRecord?.stepCount ?? 0, calories: calories)
                    }
                } else if let error = error {
                    print("칼로리 데이터 가져오기 실패: \(error.localizedDescription)")
                }
            }
            healthStore.execute(query)
        }
    }
    
    // Firestore에 데이터 저장 및 업데이트
    private func updateRunRecord(stepCount: Double, calories: Double, imageURL: String? = nil) {
        let endTime = isSimulating ? nil : Date()
        let duration = calculateDuration()
        
        // 좌표를 [[latitude, longitude]] 형식으로 변환
        let coordinatesArray = coordinates.map { [$0.latitude, $0.longitude] }
        
        let newData = RunRecordModels(
            id: nil,
            distance: calculateTotalDistance(),
            stepCount: stepCount,
            caloriesBurned: calories,
            startTime: startTime ?? Date(),
            endTime: endTime,
            duration: duration,
            imageURL: imageURL,
            coordinates: coordinatesArray
        )
        
        do {
            let ref = db.collection("RunRecordModels").document()
            try ref.setData(from: newData) { error in
                if let error = error {
                    print("Firestore 저장 실패: \(error.localizedDescription)")
                } else {
                    print("Firestore에 데이터 저장 성공")
                    DispatchQueue.main.async {
                        self.runRecord = newData
                    }
                }
            }
        } catch {
            print("Firestore 인코딩 실패: \(error.localizedDescription)")
        }
    }
    
    // 진행 시간 계산 (분 단위)
    private func calculateDuration() -> Double {
        guard let start = startTime else { return 0 }
        let end = isSimulating ? Date() : (runRecord?.endTime ?? Date())
        let seconds = end.timeIntervalSince(start)
        return seconds / 60 // 분 단위로 변환
    }
    
    // Firestore에서 모든 데이터 가져오기
    func fetchRunRecordsFromFirestore() {
        db.collection("RunRecordModels")
            .order(by: "start_time", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Firestore에서 데이터 가져오기 실패: \(error?.localizedDescription ?? "No documents")")
                    return
                }
                
                let dataList = documents.compactMap { try? $0.data(as: RunRecordModels.self) }
                DispatchQueue.main.async {
                    self.runRecordList = dataList
                    self.runRecord = dataList.first // 최신 데이터 유지
                }
            }
    }
    
    // 지도 스냅샷 캡처
    func captureMapSnapshot(mapView: MKMapView) {
        self.mapView = mapView
        let options = MKMapSnapshotter.Options()
        options.region = mapView.region
        options.size = mapView.bounds.size
        options.scale = UIScreen.main.scale
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("스냅샷 생성 실패: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // 스냅샷에 폴리곤과 경로 그리기
            UIGraphicsBeginImageContextWithOptions(snapshot.image.size, true, 0)
            snapshot.image.draw(at: .zero)
            
            if let context = UIGraphicsGetCurrentContext() {
                // 폴리곤 렌더링
                for polygon in self.polygons {
                    let points = polygon.points() // MKMapPoint 배열
                    let count = polygon.pointCount
                    var pixelPoints = [CGPoint]()
                    for i in 0..<count {
                        let mapPoint = points[i] // MKMapPoint
                        let coordinate = mapPoint.coordinate // MKMapPoint -> CLLocationCoordinate2D
                        let pixelPoint = snapshot.point(for: coordinate) // CLLocationCoordinate2D -> CGPoint
                        pixelPoints.append(pixelPoint)
                    }
                    context.setFillColor(UIColor.green.withAlphaComponent(0.5).cgColor)
                    context.setStrokeColor(UIColor.green.cgColor)
                    context.setLineWidth(4)
                    context.addLines(between: pixelPoints)
                    context.closePath()
                    context.drawPath(using: .fillStroke)
                }
                
                // 경로선 렌더링
                for polyline in self.polylines {
                    let points = polyline.points()
                    let count = polyline.pointCount
                    var pixelPoints = [CGPoint]()
                    for i in 0..<count {
                        let mapPoint = points[i] // MKMapPoint
                        let coordinate = mapPoint.coordinate // MKMapPoint -> CLLocationCoordinate2D
                        let pixelPoint = snapshot.point(for: coordinate) // CLLocationCoordinate2D -> CGPoint
                        pixelPoints.append(pixelPoint)
                    }
                    context.setStrokeColor(UIColor.systemGreen.cgColor)
                    context.setLineWidth(3)
                    context.addLines(between: pixelPoints)
                    context.strokePath()
                }
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let image = finalImage {
                // 사진 앨범에 저장
                self.saveToPhotoLibrary(image: image)
                
                // Firebase Storage에 업로드
                self.uploadImageToFirebase(image: image) { url in
                    self.updateRunRecord(
                        stepCount: self.runRecord?.stepCount ?? 0,
                        calories: self.runRecord?.caloriesBurned ?? 0,
                        imageURL: url?.absoluteString
                    )
                }
            }
        }
    }
    
    // 사진 앨범에 저장
    private func saveToPhotoLibrary(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("사진 앨범 접근 권한 없음")
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: image.pngData()!, options: nil)
            } completionHandler: { success, error in
                if success {
                    print("사진 앨범에 이미지 저장 성공")
                } else if let error = error {
                    print("사진 저장 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Firebase Storage에 이미지 업로드
    private func uploadImageToFirebase(image: UIImage, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("이미지 데이터 변환 실패")
            completion(nil)
            return
        }
        
        let storageRef = storage.reference().child("map_snapshots/\(UUID().uuidString).jpg")
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Firebase Storage 업로드 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("다운로드 URL 가져오기 실패: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    print("Firebase Storage에 이미지 업로드 성공: \(url?.absoluteString ?? "")")
                    completion(url)
                }
            }
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
            updateRunRecord(stepCount: runRecord?.stepCount ?? 0, calories: runRecord?.caloriesBurned ?? 0)
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
        startTime = Date()
        coordinates.removeAll()
        polylines.removeAll()
        polygons.removeAll()
        lastIntersectionIndex = nil
        
        clManager.startUpdatingLocation()
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let lastLocation = self.clManager.location {
                if self.isSimulating {
                    self.updateCoordinates(newCoordinate: lastLocation.coordinate)
                    self.updateRunRecord(stepCount: self.runRecord?.stepCount ?? 0, calories: self.runRecord?.caloriesBurned ?? 0)
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
        updateRunRecord(stepCount: runRecord?.stepCount ?? 0, calories: runRecord?.caloriesBurned ?? 0)
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
    
    // 교차점 감지 및 폴리곤 생성
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
                    
                    // 폴리곤 생성 시 지도 캡처
                    if let mapView = self.mapView {
                        captureMapSnapshot(mapView: mapView)
                    }
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
        
        let denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x)*(p2.y - p1.y)
        if denominator == 0 { return false }
        
        let ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
        let ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denominator
        
        return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1
    }
    
    // 총 이동 거리 계산
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
    let onPolygonAdded: (MKMapView) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.showsPointsOfInterest = false
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
                renderer.strokeColor = .systemGreen
                renderer.lineWidth = 3
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.green.withAlphaComponent(0.5)
                renderer.strokeColor = .green
                renderer.lineWidth = 4
                parent.onPolygonAdded(mapView)
                return renderer
            }
            
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "CurrentLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            //성인씨 이미지 들어가는 곳
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.image = UIImage(named: "H")
                let imageSize = CGSize(width: 60, height: 60)
                annotationView?.frame = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
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
        
        // 경로선 추가
        if !coordinates.isEmpty {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            // 지도 영역 설정
            let region = coordinateRegionForCoordinates(coordinates)
            mapView.setRegion(region, animated: true)
        }
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context _: Context) {
        // 업데이트 필요 없음 (정적 표시)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func coordinateRegionForCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), // 서울 기본 좌표
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
    
    private func toggleSimulation() {
        isSimulating ? stopAction() : startAction()
    }
}

// MARK: - 결과 뷰
struct ResultView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showResult: Bool
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            List(locationManager.runRecordList) { data in
                VStack(alignment: .leading, spacing: 6) {
                    // 경로 지도 표시
                    RouteMapView(coordinates: data.coordinateList)
                        .frame(height: 200)
                        .cornerRadius(10)
                    
                    Text(String(format: "이동 거리: %.3f m", data.distance))
                    Text(String(format: "걸음 수: %.0f 걸음", data.stepCount))
                    Text(String(format: "소모 칼로리: %.1f kcal", data.caloriesBurned))
                    Text("시작 시간: \(data.startTime, formatter: dateFormatter)")
                    Text("종료 시간: \(data.endTime.map { dateFormatter.string(from: $0) } ?? "진행 중")")
                    Text(String(format: "진행 시간: %.1f 분", data.duration))
                    if let imageURL = data.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } placeholder: {
                            ProgressView()
                                .frame(height: 200)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("활동 기록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        showResult = false
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 10)
    }
}

// MARK: - 프리뷰
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
