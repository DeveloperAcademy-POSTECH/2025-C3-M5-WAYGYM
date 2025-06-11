//
//  LocationManager.swift
//  WAY_GYM
//
//  Created by Leo on 6/9/25.
//

import Foundation
import MapKit
import CoreLocation
import HealthKit
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Photos
import FirebaseCore

// MARK: - 위치 관리 클래스
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion()
    @Published var polylines: [MKPolyline] = []
    @Published var polygons: [MKPolygon] = []
    @Published var isSimulating = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var runRecord: RunRecordModels?
    @Published var runRecordList: [RunRecordModels] = []
    // @Published var stepCount: Double = 0
    // @Published var caloriesBurned: Double = 0
    @Published var capturedAreas: [CoordinatePairWithGroup] = []
    
    private let clManager = CLLocationManager()
    private var coordinates: [CLLocationCoordinate2D] = []
    private var simulationTimer: Timer?
    private var lastIntersectionIndex: Int?
    private var startTime: Date?
    private var endTime: Date?
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
    
    // Firestore에 데이터 저장 및 업데이트
    private func updateRunRecord(imageURL: String? = nil) {
        guard let start = startTime else {
            print("⚠️ 시작 시간이 설정되지 않음")
            return
        }
        
        print("🏁 startTime: \(startTime?.description ?? "nil")")
        print("🏁 endTime: \(endTime?.description ?? "nil")")
        
        let coordinatesArray = coordinates.map { [$0.latitude, $0.longitude] }
        let capturedAreas: [CoordinatePairWithGroup] = polygons.enumerated().flatMap { (index, polygon) in
            let points = polygon.points()
            let count = polygon.pointCount
            return (0..<count).map {
                let coordinate = points[$0].coordinate
                return CoordinatePairWithGroup(latitude: coordinate.latitude, longitude: coordinate.longitude, groupId: index + 1)
            }
        }
        
        let newData = RunRecordModels(
            id: nil,
            distance: calculateTotalDistance(),
            // stepCount: stepCount,
            // caloriesBurned: calories,
            startTime: start,
            endTime: endTime,
            routeImage: imageURL,
            coordinates: coordinates.map { CoordinatePair(latitude: $0.latitude, longitude: $0.longitude) },
            capturedAreas: capturedAreas,
            capturedAreaValue: 0
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
        let end = endTime ?? Date()
        let seconds = end.timeIntervalSince(start)
        return seconds / 60
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
                    self.runRecord = dataList.first
                }
            }
    }
    
    // 시뮬레이터 좌표 설정을 위한 초기화
//    func setupSimulatorLocation() {
//        #if targetEnvironment(simulator)
//        // 시뮬레이터 환경에서 초기 좌표 설정 (예: 서울역)
//        let initialCoordinate = CLLocationCoordinate2D(latitude: 37.554678, longitude: 126.975147)
//        currentLocation = initialCoordinate
//        updateRegion(coordinate: initialCoordinate)
//        print("시뮬레이터 초기 좌표 설정: \(initialCoordinate.latitude), \(initialCoordinate.longitude)")
//        #endif
//    }
    
    // 네트워크 상태 확인
//    private func isNetworkAvailable() -> Bool {
//        let monitor = NWPathMonitor()
//        let semaphore = DispatchSemaphore(value: 0)
//        var isConnected = false
//
//        monitor.pathUpdateHandler = { path in
//            isConnected = path.status == .satisfied
//            semaphore.signal()
//        }
//        monitor.start(queue: .global())
//        semaphore.wait()
//        monitor.cancel()
//        return isConnected
//    }
    
    // 디스크 공간 확인
//    private func hasEnoughDiskSpace(for imageData: Data) -> Bool {
//        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
//        let freeSpace = attributes?[.systemFreeSize] as? Int64 ?? 0
//        return freeSpace > Int64(imageData.count)
//    }
    
    // 지도 스냅샷 캡처
//    func captureMapSnapshot(mapView: MKMapView) {
//        self.mapView = mapView
//        let options = MKMapSnapshotter.Options()
//        options.region = mapView.region
//        options.size = mapView.bounds.size
//        options.scale = UIScreen.main.scale
//        options.mapType = .standard // VLR 의존 가능성 있는 하이브리드/위성 모드 피하기
//
//        let snapshotter = MKMapSnapshotter(options: options)
//        snapshotter.start(with: .main) { snapshot, error in
//            guard let snapshot = snapshot, error == nil else {
//                print("스냅샷 생성 실패: \(error?.localizedDescription ?? "Unknown error")")
//                return
//            }
//
//            UIGraphicsBeginImageContextWithOptions(snapshot.image.size, true, 0)
//            snapshot.image.draw(at: .zero)
//
//            if let context = UIGraphicsGetCurrentContext() {
//                for polygon in self.polygons {
//                    let points = polygon.points()
//                    let count = polygon.pointCount
//                    var pixelPoints = [CGPoint]()
//                    for i in 0..<count {
//                        let mapPoint = points[i]
//                        let coordinate = mapPoint.coordinate
//                        let pixelPoint = snapshot.point(for: coordinate)
//                        pixelPoints.append(pixelPoint)
//                    }
//                    context.setFillColor(UIColor.green.withAlphaComponent(0.5).cgColor)
//                    context.setStrokeColor(UIColor.green.cgColor)
//                    context.setLineWidth(4)
//                    context.addLines(between: pixelPoints)
//                    context.closePath()
//                    context.drawPath(using: .fillStroke)
//                }
//
//                for polyline in self.polylines {
//                    let points = polyline.points()
//                    let count = polyline.pointCount
//                    var pixelPoints = [CGPoint]()
//                    for i in 0..<count {
//                        let mapPoint = points[i]
//                        let coordinate = mapPoint.coordinate
//                        let pixelPoint = snapshot.point(for: coordinate)
//                        pixelPoints.append(pixelPoint)
//                    }
//                    context.setStrokeColor(UIColor.systemGreen.cgColor)
//                    context.setLineWidth(3)
//                    context.addLines(between: pixelPoints)
//                    context.strokePath()
//                }
//            }
//
//            guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else {
//                print("최종 이미지 생성 실패")
//                UIGraphicsEndImageContext()
//                return
//            }
//            UIGraphicsEndImageContext()
//
//            // 사진 앨범 저장
//            self.saveToPhotoLibrary(image: finalImage) { success in
//                if success {
//                    // Firebase 업로드
//                    self.uploadImageToFirebase(image: finalImage) { url in
//                        // Firestore 업데이트
//                        self.updateRunRecord(imageURL: url?.absoluteString)
//                    }
//                }
//            }
//
//            // Metal 렌더링 완료 대기
//            mapView.setNeedsDisplay()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                // Metal 렌더링 완료 후 처리
//            }
//        }
//    }
    
    // 사진 앨범에 저장
//    private func saveToPhotoLibrary(image: UIImage, completion: @escaping (Bool) -> Void = { _ in }) {
//        PHPhotoLibrary.requestAuthorization { status in
//            guard status == .authorized else {
//                print("사진 앨범 접근 권한 거부됨: \(status.rawValue)")
//                completion(false)
//                return
//            }
//
//            PHPhotoLibrary.shared().performChanges {
//                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: image.jpegData(compressionQuality: 0.8)!, options: nil)
//            } completionHandler: { success, error in
//                DispatchQueue.main.async {
//                    if success {
//                        print("사진 앨범에 이미지 저장 성공")
//                        completion(true)
//                    } else if let error = error {
//                        print("사진 저장 실패: \(error.localizedDescription)")
//                        completion(false)
//                    }
//                }
//            }
//        }
//    }
    
    // Firebase Storage에 이미지 업로드
//    private func uploadImageToFirebase(image: UIImage, completion: @escaping (URL?) -> Void) {
//        // 네트워크 상태 확인
//        guard isNetworkAvailable() else {
//            print("네트워크 연결 없음")
//            completion(nil)
//            return
//        }
//
//        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
//            print("이미지 데이터 변환 실패")
//            completion(nil)
//            return
//        }
//
//        // 디스크 공간 확인
//        guard hasEnoughDiskSpace(for: imageData) else {
//            print("디스크 공간 부족")
//            completion(nil)
//            return
//        }
//
//        // 로컬에 임시 파일 저장
//        let fileName = "\(UUID().uuidString).jpg"
//        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
//        do {
//            try imageData.write(to: fileURL)
//            print("로컬 파일 저장 성공: \(fileURL.path)")
//        } catch {
//            print("로컬 파일 저장 실패: \(error.localizedDescription)")
//            completion(nil)
//            return
//        }
//
//        // Firebase Storage 업로드
//        let storageRef = storage.reference().child("map_snapshots/\(fileName)")
//        storageRef.putFile(from: fileURL, metadata: nil) { metadata, error in
//            if let error = error {
//                print("Firebase Storage 업로드 실패: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//
//            storageRef.downloadURL { url, error in
//                if let error = error {
//                    print("다운로드 URL 가져오기 실패: \(error.localizedDescription)")
//                    completion(nil)
//                } else {
//                    print("Firebase Storage에 이미지 업로드 성공: \(url?.absoluteString ?? "")")
//                    // 로컬 파일 삭제
//                    try? FileManager.default.removeItem(at: fileURL)
//                    completion(url)
//                }
//            }
//        }
//    }
    
    // CLLocationManagerDelegate: 위치 권한 변경 처리
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            clManager.startUpdatingLocation()
        }
    }
    
    // CLLocationManagerDelegate: 위치 업데이트 처리
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard let location = locations.last else { return }
//        let newCoordinate = location.coordinate
//        currentLocation = newCoordinate
//        if isSimulating {
//            updateCoordinates(newCoordinate: newCoordinate)
//            // updateRunRecord(stepCount: stepCount, calories: caloriesBurned)
//        }
//        updateRegion(coordinate: newCoordinate)
//    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 좌표 필터링: 정확도 100m 이상 또는 음수인 경우 무시
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 100 else {
            print("부정확한 좌표 무시: accuracy = \(location.horizontalAccuracy)")
            return
        }
        
        // 최신 데이터인지 확인 (5초 이내)
        let timeInterval = abs(location.timestamp.timeIntervalSinceNow)
        guard timeInterval < 5 else {
            print("오래된 좌표 무시: timestamp = \(location.timestamp)")
            return
        }
        
        let newCoordinate = location.coordinate
        print("유효 좌표 수신: \(newCoordinate.latitude), \(newCoordinate.longitude)")
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
        guard !isSimulating else {
            print("🛑 이미 시뮬레이션 중이므로 실행 안 함")
            return
        }
        print("🚨 startSimulation() 실행됨") // ← 이게 예상치 못하게 찍히면 자동 호출임

        coordinates.removeAll()
        isSimulating = true
        startTime = Date()
        endTime = nil
        polylines.removeAll()
        polygons.removeAll()
        lastIntersectionIndex = nil
        
        clManager.startUpdatingLocation()
        
        simulationTimer = Timer
            .scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
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
        endTime = Date()
        simulationTimer?.invalidate()
        clManager.stopUpdatingLocation()
        self.updateRunRecord()
    }
    
    // 현재 위치로 지도 이동
    func moveToCurrentLocation() {
        clManager.requestWhenInUseAuthorization()
        
        if let currentLocation = clManager.location {
            print("📍 Current location available: \(currentLocation.coordinate)")
            updateRegion(coordinate: currentLocation.coordinate)
            self.currentLocation = currentLocation.coordinate
        } else {
            print("⏳ No current location available yet.")
            clManager.startUpdatingLocation()
        }
    }
    
    // 좌표 업데이트
    private func updateCoordinates(newCoordinate: CLLocationCoordinate2D) {
        // 이상치 필터링
        guard isValidCoordinate(newCoordinate, lastCoordinate: coordinates.last) else {
            print("좌표 업데이트 무시: \(newCoordinate.latitude), \(newCoordinate.longitude)")
            return
        }
        
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
                    
                    let areaCoordinatePairs = polygonCoordinates.map {
                        CoordinatePairWithGroup(latitude: $0.latitude, longitude: $0.longitude, groupId: polygons.count)
                    }
                    capturedAreas.append(contentsOf: areaCoordinatePairs)
                    // runRecord 업데이트는 updateRunRecord에서 처리
                    lastIntersectionIndex = coordinates.count - 2
                    
                    if let mapView = self.mapView {
                        // captureMapSnapshot(mapView: mapView)
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
    
    // 저장된 면적을 지도에 불러오기
    func loadCapturedPolygons(from records: [RunRecordModels]) {
        var result: [MKPolygon] = []

        for record in records {
            // groupId 기준으로 그룹핑
            let grouped = Dictionary(grouping: record.capturedAreas, by: { $0.groupId })

            for (_, group) in grouped {
                let coords = group.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                let polygon = MKPolygon(coordinates: coords, count: coords.count)
                result.append(polygon)
            }
        }

        self.polygons = result
    }
    private func isValidCoordinate(_ newCoordinate: CLLocationCoordinate2D, lastCoordinate: CLLocationCoordinate2D?) -> Bool {
        guard let last = lastCoordinate else { return true } // 첫 좌표는 항상 유효
        let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
        
        // 거리 계산
        let distance = lastLocation.distance(from: newLocation)
        // 최대 허용 거리: 500m (1초에 500m 이상 이동은 비현실적)
        guard distance < 500 else {
            print("비현실적 거리 감지: \(distance)m")
            return false
        }
        
        // 속도 계산 (1초 간격 기준)
        let speed = distance / 1.0 // m/s
        // 최대 허용 속도: 13.89 m/s (약 50km/h, 일반적인 달리기/자전거 속도)
        guard speed < 13.89 else {
            print("비현실적 속도 감지: \(speed)m/s")
            return false
        }
        
        return true
    }
}
