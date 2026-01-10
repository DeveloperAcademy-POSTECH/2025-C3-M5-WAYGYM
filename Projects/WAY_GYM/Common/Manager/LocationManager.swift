import Foundation
import MapKit
import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Photos
import FirebaseCore
import FirebaseAuth

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion()
    @Published var polylines: [MKPolyline] = []
    @Published var polygons: [MKPolygon] = []
    @Published var isSimulating = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var runRecord: RunRecordModel?
    @Published var runRecordList: [RunRecordModel] = []
    @Published var capturedAreas: [CoordinatePairWithGroup] = []
    @Published var isAreaActive = false
    
    private let clManager = CLLocationManager()
    private var coordinates: [CLLocationCoordinate2D] = []
    private var simulationTimer: Timer?
    private var lastIntersectionIndex: Int?
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
    
    // MARK: - 초기 세팅, 런닝 지역 가져오기
    func extractRegionName(from placemark: CLPlacemark) -> String? {
        // 1) 1차 시도: placemark 필드에서 바로 추출
        let province = placemark.administrativeArea // 예: 경기도/서울특별시 (사용 안함)
        let si = placemark.locality                 // 예: 용인시/서울특별시/하남시
        let guOrGunRaw = placemark.subAdministrativeArea // 예: 처인구/마포구(일부 기기/지역에서 비어있을 수 있음)
        let dongEupMyeonRaw = placemark.subLocality      // 예: 역삼동/모현읍/○○면

        // 헬퍼: 접미사 체크
        func endsWith(_ text: String?, suffixes: [String]) -> Bool {
            guard let t = text, !t.isEmpty else { return false }
            return suffixes.contains { t.hasSuffix($0) }
        }

        // 정규화된 후보
        var guOrGun: String? = endsWith(guOrGunRaw, suffixes: ["구","군"]) ? guOrGunRaw : nil
        var dongEupMyeon: String? = endsWith(dongEupMyeonRaw, suffixes: ["동","읍","면"]) ? dongEupMyeonRaw : nil

        // 2) 2차 시도: FormattedAddressLines에서 파싱 (서울특별시 등 일부 케이스 보완)
        if (guOrGun == nil || dongEupMyeon == nil),
           let lines = placemark.addressDictionary?["FormattedAddressLines"] as? [String],
           let full = lines.first {
            // "대한민국 " 제거 후 공백 분리
            let trimmed = full.replacingOccurrences(of: "대한민국 ", with: "")
            let comps = trimmed.split(separator: " ").map(String.init)

            // 구/군 토큰과 동/읍/면 토큰 탐색
            var foundGuGun: String?
            var foundDongEupMyeon: String?
            for i in 0..<comps.count {
                let token = comps[i]
                if foundGuGun == nil && (token.hasSuffix("구") || token.hasSuffix("군")) {
                    foundGuGun = token
                }
                if foundDongEupMyeon == nil && (token.hasSuffix("동") || token.hasSuffix("읍") || token.hasSuffix("면")) {
                    foundDongEupMyeon = token
                }
            }
            if guOrGun == nil { guOrGun = foundGuGun }
            if dongEupMyeon == nil { dongEupMyeon = foundDongEupMyeon }
        }

        // 3) 최종 조합 규칙
        if let gu = guOrGun, let dem = dongEupMyeon { return "\(gu) \(dem)" }
        if let city = si, city != province, let dem = dongEupMyeon { return "\(city) \(dem)" }
        if let gu = guOrGun { return gu }                // 동/읍/면이 없을 때 최소한 구/군만이라도
        if let dem = dongEupMyeon { return dem }         // 구/군이 전혀 없을 때
        return nil
    }
    
    // MARK: - 런닝 중
    // 시뮬레이션 중일 때 좌표 갱신
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
                    self.updateCoordinates(newCoordinate: lastLocation.coordinate)
                }
                self.currentLocation = lastLocation.coordinate
                self.updateRegion(coordinate: lastLocation.coordinate)
            }
        }
    }
    
    func stopSimulation() {
        isSimulating = false
        endTime = Date()
        simulationTimer?.invalidate()
        clManager.stopUpdatingLocation()
        self.updateRunRecord()
    }
    
    // 현재 세션의 좌표/폴리곤을 러닝 기록 데이터로 변환하고 Firestore에 저장.
    func updateRunRecord(imageURL: String? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print ("사용자 UID를 가져올 수 없습니다")
            return
        }
        
        guard let start = startTime else {
            print("⚠️ 시작 시간이 설정되지 않았습니다")
            return
        }
        
        let coordinatesArray = coordinates.map { [$0.latitude, $0.longitude] }
        let capturedAreas: [CoordinatePairWithGroup] = polygons.enumerated().flatMap { (index, polygon) in
            let points = polygon.points()
            let count = polygon.pointCount
            return (0..<count).map {
                let coordinate = points[$0].coordinate
                return CoordinatePairWithGroup(latitude: coordinate.latitude, longitude: coordinate.longitude, groupId: index + 1)
            }
        }
        
        let newData = RunRecordModel(
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
            // let ref = db.collection("RunRecordModels").document()
            let ref = db.collection("RunRecordModels").document(uid).collection("runRecords").document()
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
    
    // 좌표 유효성 검사
    private func updateCoordinates(newCoordinate: CLLocationCoordinate2D) {
        guard isValidCoordinate(newCoordinate, lastCoordinate: coordinates.last) else {
            print("좌표 업데이트 무시: \(newCoordinate.latitude), \(newCoordinate.longitude)")
            return
        }
        
        coordinates.append(newCoordinate)
        updateMapOverlays()
        checkForPolygon()
        updateRegion(coordinate: newCoordinate)
    }
    
    // MARK: - 메인 화면
    // 서버에서 런닝 기록 가져오기. 딴 땅을 메인뷰에서 띄우기 위함
    func fetchRunRecordsFromFirestore() {
        firestoreListener?.remove()
        
        // firestoreListener = db.collection("RunRecordModels")
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 사용자 UID를 가져올 수 없습니다.")
            return
        }
        
        firestoreListener = db.collection("RunRecordModels").document(uid).collection("runRecords")
            .order(by: "start_time", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Firestore에서 데이터 가져오기 실패: \(error?.localizedDescription ?? "No documents")")
                    return
                }
                
                let dataList = documents.compactMap { try? $0.data(as: RunRecordModel.self) }
                DispatchQueue.main.async {
                    self.runRecordList = dataList
                    self.runRecord = dataList.first
                    self.polylines.removeAll()
                }
            }
    }
    
    // 현재 위치 버튼
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
    
    // MARK: - 지도 위 땅 그리기
    // 마지막 교차 인덱스 이후의 좌표들로 최근 Polyline 생성
    private func updateMapOverlays() {
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
    
    // 좌표 수가 4개 이상인 경우, 새로 추가된 선분이 기존 선분과 교차하는지 검사.
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
                    lastIntersectionIndex = coordinates.count - 2
                }
                break
            }
        }
    }
    
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
    
    // MARK: - 지도 위 땅 그리기
    // 지도의 center를 현재 좌표로 맞춤
    private func updateRegion(coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }
    
    func loadCapturedPolygons(from records: [RunRecordModel]) {
        var result: [MKPolygon] = []
        for record in records {
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
    
    private func isValidCoordinate(_ newCoordinate: CLLocationCoordinate2D, lastCoordinate: CLLocationCoordinate2D?) -> Bool {
        // 1. 좌표 범위 검사
        guard newCoordinate.latitude >= -90 && newCoordinate.latitude <= 90 &&
                newCoordinate.longitude >= -180 && newCoordinate.longitude <= 180 else {
            print("유효하지 않은 좌표 범위: \(newCoordinate)")
            return false
        }
        
        guard let last = lastCoordinate else { return true }
        
        // 2. 거리와 속도 검사
        let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
        let distance = lastLocation.distance(from: newLocation)
        
        // 50m 이상 이동한 경우 무시
        guard distance < 50 else {
            print("비현실적 거리 감지: \(distance)m")
            return false
        }
        
        // 20km/h (약 5.56m/s) 이상의 속도는 무시
        let speed = distance / 1.0  // 1초당 속도
        guard speed < 5.56 else {
            print("비현실적 속도 감지: \(speed)m/s (약 \(speed * 3.6)km/h)")
            return false
        }
        return true
    }
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
        coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    // MARK: - 델리게이트 함수
    // 권한 확인/위치 추적 시작 트리거
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            clManager.startUpdatingLocation()
        }
    }
    
    // GPS에서 새로운 위치 값이 들어올 때마다 자동으로 호출
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
        // print("유효 좌표 수신: \(newCoordinate.latitude), \(newCoordinate.longitude)")
        currentLocation = newCoordinate
        
        // 시뮬레이션 중일 때만 위치 업데이트 및 유효성 검사 수행
        if isSimulating {
            updateCoordinates(newCoordinate: newCoordinate)
        }
        updateRegion(coordinate: newCoordinate)
    }
}

