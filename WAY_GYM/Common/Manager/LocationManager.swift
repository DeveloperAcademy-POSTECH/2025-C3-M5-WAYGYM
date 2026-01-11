import Foundation
import MapKit
import CoreLocation
import HealthKit
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Photos
import FirebaseCore

// - CLLocationManager에게 사용자 위치를 받아서, 앱에서 쓰기 좋은 상태(@Published)로 가공한다.
// - 러닝(시뮬레이션) 중: 경로 좌표를 누적하고 폴리라인/폴리곤 오버레이 데이터를 만든다.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let clManager = CLLocationManager() /// GPS 위치를 받아오는 시스템 객체
    @Published var region = MKCoordinateRegion() // 지도가 보여줄 영역 (센터+줌)
    @Published var currentLocation: CLLocationCoordinate2D? // 현재 위치 표시하는 캐릭터 좌표
    
    @Published var polylines: [MKPolyline] = []
    @Published var polygons: [MKPolygon] = []
    
    @Published var isSimulating = false /// 러닝(경로 추적) 중인지 여부. (UI 표시 상태가 아니라, 좌표 누적/경로 생성 로직을 켤지 말지 결정)
    
    /// 서버에서 가져오거나 보낼 런닝 기록 모델
    @Published var runRecord: RunRecordModels?
    @Published var runRecordList: [RunRecordModels] = [] /// 서버에서 받아온 모든 런닝 기록
    
    private var coordinates: [CLLocationCoordinate2D] = [] /// 러닝 중 누적된 좌표 원본 (모든 이동 좌표)
    /// 폴리곤을 더 세부 데이터로 저장하는 용도
    @Published var capturedAreas: [CoordinatePairWithGroup] = [] // 닫힌 영역의 꼭짓점들을 모아서 저장한 배열
    @Published var isAreaActive = false
    
    
    private var simulationTimer: Timer? /// 1초마다 위치를 읽어오는 타이머
    private var lastIntersectionIndex: Int? /// 폴리곤이 만들어진 지점 이후부터 새 선을 만들기 위한 기준 인덱스

    private var startTime: Date?
    private var endTime: Date?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var firestoreListener: ListenerRegistration?

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.requestWhenInUseAuthorization()
    }

    func updateRunRecord(imageURL: String? = nil) {
    guard let start = startTime else {
        print("⚠️ 시작 시간이 설정되지 않았습니다")
        return
    }

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

    /// 서버에서 런닝 기록 가져오기
    func fetchRunRecordsFromFirestore() {
        firestoreListener?.remove()
        
        firestoreListener = db.collection("RunRecordModels")
            .order(by: "start_time", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Firestore에서 데이터 가져오기 실패: \(error?.localizedDescription ?? "No documents")")
                    return
                }

                let dataList = documents.compactMap { try? $0.data(as: RunRecordModels.self) }
                DispatchQueue.main.async {
                    self.runRecordList = dataList
                    self.runRecord = dataList.first
                    self.polylines.removeAll()
                }
            }
    }

    // MARK: - 런닝 중
    func startSimulation() {
        guard clManager.authorizationStatus == .authorizedWhenInUse || clManager.authorizationStatus == .authorizedAlways else {
            clManager.requestWhenInUseAuthorization()
            return
        }
//        guard !isSimulating else {
//            print("🛑 이미 시뮬레이션 중이므로 실행 안 함")
//            return
//        }
        print("🚨 startSimulation() 실행됨")
        
        coordinates.removeAll()
        isSimulating = true
        startTime = Date()
        endTime = nil
        polylines.removeAll()
        polygons.removeAll()
        lastIntersectionIndex = nil
        
        clManager.startUpdatingLocation()
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let lastLocation = self.clManager.location {
                if self.isSimulating {
                    self.updateRunCoordinateIfValid(newCoordinate: lastLocation.coordinate)
                }
                self.currentLocation = lastLocation.coordinate
                self.centerMap(on: lastLocation.coordinate)
            }
        }
    }

    func stopSimulation() {
        isSimulating = false
        endTime = Date()
        simulationTimer?.invalidate()
        simulationTimer = nil
        self.updateRunRecord()
        
        DispatchQueue.main.async {
            self.polylines.removeAll()
            self.polygons.removeAll()
            self.capturedAreas.removeAll()
        }
        coordinates.removeAll()
        lastIntersectionIndex = nil
    }
    
    /// 런닝 시: 좌표가 유효한지 확인
    private func updateRunCoordinateIfValid(newCoordinate: CLLocationCoordinate2D) {
        guard isValidCoordinate(newCoordinate, lastCoordinate: coordinates.last) else {
            print("좌표 업데이트 무시: \(newCoordinate.latitude), \(newCoordinate.longitude)")
            return
        }
        
        coordinates.append(newCoordinate)
                drawPolylines()
        checkAndDrawPolygon()
        centerMap(on: newCoordinate)
    }
    
    /// 최근 좌표들을 기반으로 MKPolyline 만들기
    private func drawPolylines() {
        let startIdx = (lastIntersectionIndex ?? -1) + 1
        guard startIdx + 1 < coordinates.count else { return }
        
        let recentCoordinates = Array(coordinates[startIdx...])
        let polyline = MKPolyline(coordinates: recentCoordinates, count: recentCoordinates.count)
        if !isAreaActive {
            polylines.append(polyline)
            print("Polyline added: \(polylines.count)")
        } else {
            print("Polyline skipped due to isAreaActive")
        }
    }
    
    /// 새 선분이 이전에 그렸던 선분들과 교차하는지 검사해서 교차하면 닫힌 영역(폴리곤)을 만든다
    private func checkAndDrawPolygon() {
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
                    lastIntersectionIndex = coordinates.count - 2
                }
                break
            }
        }
    }

    /// 두 선분이 교차하는지 수학적으로 판단
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
    
     /// 교차한다면 “정확히 어디서 교차하는지” 좌표를 계산
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
    
    /// 새 좌표가 현실적인 러닝 좌표인지 검사
    private func isValidCoordinate(
        _ newCoordinate: CLLocationCoordinate2D,
        lastCoordinate: CLLocationCoordinate2D? = nil,
        maxDistanceMeters: Double = 50,
        maxSpeedMps: Double = 5.56,
        sampleIntervalSeconds: Double = 1.0
    ) -> Bool {
        // 1) 범위 체크
        guard (-90...90).contains(newCoordinate.latitude),
              (-180...180).contains(newCoordinate.longitude) else {
            print("유효하지 않은 좌표 범위: \(newCoordinate)")
            return false
        }

        // last가 없으면 범위만 통과시키고 끝
        guard let last = lastCoordinate else { return true }

        // 2) 거리/속도 체크
        let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let newLoc  = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
        let distance = lastLoc.distance(from: newLoc)

        guard distance < maxDistanceMeters else {
            print("비현실적 거리 감지: \(distance)m")
            return false
        }

        let speed = distance / sampleIntervalSeconds
        guard speed < maxSpeedMps else {
            print("비현실적 속도 감지: \(speed)m/s (약 \(speed * 3.6)km/h)")
            return false
        }

        return true
    }
     
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
    
    // MARK: - 기본 지도 앱 기능
    /// 사용자의 현위치로 지도 이동
    func moveToCurrentLocation() {
        clManager.requestWhenInUseAuthorization()
        if let currentLocation = clManager.location {
            print("📍 Current location available: \(currentLocation.coordinate)")
            centerMap(on: currentLocation.coordinate)
            self.currentLocation = currentLocation.coordinate
        } else {
            print("⏳ No current location available yet.")
            clManager.startUpdatingLocation()
        }
    }
    
    /// 이 좌표를 중심으로 지도 화면을 이동함
    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }
    
    /// 사용자의 전체 런닝 기록 중 영역만 가져옴
    func loadCapturedPolygons(from records: [RunRecordModels]) {
        var result: [MKPolygon] = []
        for record in records {
            /// 러닝 경로 전체 좌표로 폴리곤 만들기
            let coords = record.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            if coords.count >= 3 && coords.allSatisfy({ isValidCoordinate($0) }) {
                var closedCoords = coords
                if closedCoords.first?.latitude != closedCoords.last?.latitude || 
                   closedCoords.first?.longitude != closedCoords.last?.longitude {
                    closedCoords.append(closedCoords.first!)
                }
                let polygon = MKPolygon(coordinates: closedCoords, count: closedCoords.count)
                result.append(polygon)
            }
        }
        self.polygons = result
    }
    
    /// 권한이 바뀔 때 호출되는 delegate.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            clManager.startUpdatingLocation()
        }
    }
    
    /// GPS에서 “새 위치”가 들어올 때마다 호출되는 delegate.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 100 else {
            print("부정확한 좌표 무시: accuracy = \(location.horizontalAccuracy)")
            return
        }
        
        let timeInterval = abs(location.timestamp.timeIntervalSinceNow)
        guard timeInterval < 5 else {
            print("오래된 좌표 무시: timestamp = \(location.timestamp)")
            return
        }
        
        let newCoordinate = location.coordinate
        print("유효 좌표 수신: \(newCoordinate.latitude), \(newCoordinate.longitude)")
        currentLocation = newCoordinate
        
        // 시뮬레이션 중일 때만 위치 업데이트 및 유효성 검사 수행
        if isSimulating {
            updateRunCoordinateIfValid(newCoordinate: newCoordinate)
        }
        centerMap(on: newCoordinate)
    }
}
