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
    
    private let gridSize: Double = 0.0005 // 셀 한 변 크기
    @Published private(set) var capturedCellIds: Set<String> = [] /// 닫힌 영역 내, 사용자가 획득한 셀의 좌표
    
    private var simulationTimer: Timer? /// 1초마다 위치를 읽어오는 타이머

    // MARK: - DEBUG Mock Route (방구석 개발러용)
    #if DEBUG
    /// true면 실제 GPS 대신 mock 좌표로 이동한다. (필요 없으면 false)
    private var useMockRoute: Bool = true
    private var mockRoute: [CLLocationCoordinate2D] = []
    private var mockRouteIndex: Int = 0
    private var mockDriftStep: Int = 0

    /// 기준 좌표 주변으로 "되돌아가며 교차"하는 경로를 만든다.
    /// - 목표: gridSize(0.001) 셀을 실제로 덮을 수 있을 만큼(> 0.001도) 큰 루프를 만든다.
    /// - 단, 1초마다 이동할 때 speed limit(5.56m/s)을 넘지 않도록 한 step은 약 5~6m로 유지.
    private func buildMockRoute(around base: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        // 목표
        // - 사방팔방(곡선/사선/지그재그)으로 움직이되
        // - 1초 step은 약 4~5m로 유지해서 speed limit(5.56m/s) 아래
        // - 중간에 과거 지점으로 "서서히" 되돌아가 교차를 만들어 루프 감지 트리거
        // - gridSize(0.0005)보다 충분히 큰 영역을 커버

        // 위도 0.000045 ≈ 5m 내외 (경도는 위도에 따라 m가 더 작아져서 약간 더 크게 잡아도 안전)
        let stepLat: Double = 0.00004
        let stepLng: Double = 0.00005

        func add(_ arr: inout [CLLocationCoordinate2D], _ c: CLLocationCoordinate2D) {
            arr.append(c)
        }

        func moveToward(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
            // to 방향으로 한 step만큼 이동 (대각선이라도 step 크기 자체를 제한)
            let dLat = to.latitude - from.latitude
            let dLng = to.longitude - from.longitude
            let len = max(1e-12, sqrt(dLat * dLat + dLng * dLng))
            let nLat = dLat / len
            let nLng = dLng / len
            return CLLocationCoordinate2D(
                latitude: from.latitude + nLat * stepLat,
                longitude: from.longitude + nLng * stepLng
            )
        }

        var route: [CLLocationCoordinate2D] = []
        var pos = base
        add(&route, pos)

        // 1) 사방팔방 곡선 이동(결정론적 패턴): angle이 계속 변하면서 지그재그/곡선이 됨
        //    - 순수 random 대신 sin/cos 혼합으로 재현 가능
        let total = 180
        for i in 1...total {
            let t = Double(i)
            // 각도가 천천히 돌면서, 중간중간 방향이 튀는 느낌(사선/곡선)
            let angle = (t * 0.22)
                + sin(t * 0.11) * 1.15
                + cos(t * 0.07) * 0.85

            let dLat = sin(angle) * stepLat
            let dLng = cos(angle) * stepLng

            pos = CLLocationCoordinate2D(latitude: pos.latitude + dLat, longitude: pos.longitude + dLng)
            add(&route, pos)
        }

        // 2) 교차를 강제로 만들기: 과거의 한 지점을 목표로 "서서히" 접근
        //    - 큰 점프가 아니라 여러 step으로 이동해서 speed check를 통과
        if route.count > 60 {
            let target = route[40] // 충분히 과거 지점
            for _ in 0..<35 {
                pos = moveToward(from: pos, to: target)
                add(&route, pos)
            }
        }

        // 3) 다시 사방팔방으로 한 번 더 돌아서 루프가 닫힐 확률 증가
        let total2 = 120
        for i in 1...total2 {
            let t = Double(i) + 1000 // phase shift
            let angle = (t * 0.18)
                + sin(t * 0.09) * 1.25
                + cos(t * 0.05) * 0.95

            let dLat = sin(angle) * stepLat
            let dLng = cos(angle) * stepLng

            pos = CLLocationCoordinate2D(latitude: pos.latitude + dLat, longitude: pos.longitude + dLng)
            add(&route, pos)
        }

        // 4) 시작점 근처로 천천히 복귀(되돌아가기)해서 폐구간 생성 확률을 더 올림
        for _ in 0..<45 {
            pos = moveToward(from: pos, to: base)
            add(&route, pos)
        }

        return route
    }

    private func nextMockCoordinate() -> CLLocationCoordinate2D? {
        guard !mockRoute.isEmpty else { return nil }

        // 현재 포인트 반환
        let coord = mockRoute[mockRouteIndex]
        mockRouteIndex += 1

        // 한 사이클 끝나면: 현재 위치를 기준으로 다시 경로 생성 (연속성 유지)
        if mockRouteIndex >= mockRoute.count {
            mockRouteIndex = 0
            mockDriftStep += 1

            // 몇 사이클마다 기준점을 살짝 이동해서 "같은 곳만 돈다" 느낌 제거
            let driftLat = Double(mockDriftStep % 5) * 0.00015 // ~15~20m씩 누적 느낌
            let driftLng = Double(mockDriftStep % 5) * 0.00015

            let base = CLLocationCoordinate2D(latitude: coord.latitude + driftLat, longitude: coord.longitude + driftLng)
            mockRoute = buildMockRoute(around: base)
            print("🧪 Mock route rebuilt. driftStep=\(mockDriftStep) points=\(mockRoute.count)")
        }

        return coord
    }
    #endif
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
            capturedAreaValue: 0,
            capturedCellIds: Array(self.capturedCellIds)
        )

        do {
            let ref = db.collection("RunRecordModels").document()
            try ref.setData(from: newData) { error in
                if let error = error {
                    print("Firestore 저장 실패: \(error.localizedDescription)")
                } else {
                    print("Firestore에 데이터 저장 성공")

                    // ✅ 셀 점령 결과도 같은 문서에 저장 (merge)
                    let cellsArray = Array(self.capturedCellIds)
                    ref.setData(["capturedCellIds": cellsArray], merge: true) { err in
                        if let err = err {
                            print("capturedCellIds 저장 실패: \(err.localizedDescription)")
                        } else {
                            print("capturedCellIds 저장 성공: \(cellsArray.count)개")
                        }
                    }

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

        // mock 모드에서는 실제 GPS 업데이트를 꺼서 state 덮어쓰기를 방지
        #if DEBUG
        if useMockRoute {
            clManager.stopUpdatingLocation()
        }
        #endif

        clManager.startUpdatingLocation()
        
        // DEBUG mock route 준비 (기준점: 현재 위치가 없으면 임의의 기준 좌표 사용)
        #if DEBUG
        if useMockRoute {
            let base = self.currentLocation
                ?? self.clManager.location?.coordinate
                ?? CLLocationCoordinate2D(latitude: 37.3317, longitude: -122.0301)
            self.mockRoute = buildMockRoute(around: base)
            self.mockRouteIndex = 0
            print("🧪 Mock route enabled. points=\(mockRoute.count)")
        }
        #endif

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isSimulating else { return }

            #if DEBUG
            if self.useMockRoute {
                if let mock = self.nextMockCoordinate() {
                    self.updateRunCoordinateIfValid(newCoordinate: mock)
                    self.currentLocation = mock
                    self.centerMap(on: mock)
                }
                return
            }
            #endif

            if let lastLocation = self.clManager.location {
                self.updateRunCoordinateIfValid(newCoordinate: lastLocation.coordinate)
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
        #if DEBUG
        mockRoute.removeAll()
        mockRouteIndex = 0
        mockDriftStep = 0
        #endif
        self.updateRunRecord()
        
        DispatchQueue.main.async {
            self.polylines.removeAll()
            self.polygons.removeAll()
            self.capturedAreas.removeAll()
            self.capturedCellIds.removeAll()
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
    
    // MARK: - Capture cells inside a closed polygon
    /// 셀 id는 셀의 원점(lat, lng)을 "lat,lng" 문자열로 저장
    private func cellId(lat: Double, lng: Double) -> String {
        "\(lat),\(lng)"
    }

    /// 주어진 좌표가 속한 셀의 원점을 반환 (gridSize 단위로 내림)
    private func cellOrigin(for coordinate: CLLocationCoordinate2D) -> (lat: Double, lng: Double) {
        let lat = floor(coordinate.latitude / gridSize) * gridSize
        let lng = floor(coordinate.longitude / gridSize) * gridSize
        return (lat, lng)
    }

    /// 셀 원점(lat,lng)으로부터 셀 중심점 좌표를 만든다
    private func cellCenter(lat: Double, lng: Double) -> CLLocationCoordinate2D {
        let half = gridSize / 2
        return CLLocationCoordinate2D(latitude: lat + half, longitude: lng + half)
    }

    /// 폴리곤 좌표들의 바운딩 박스(최소 사각형 범위)
    private func polygonBounds(_ polygon: [CLLocationCoordinate2D]) -> (minLat: Double, minLng: Double, maxLat: Double, maxLng: Double)? {
        guard let first = polygon.first else { return nil }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLng = first.longitude
        var maxLng = first.longitude

        for p in polygon.dropFirst() {
            minLat = min(minLat, p.latitude)
            maxLat = max(maxLat, p.latitude)
            minLng = min(minLng, p.longitude)
            maxLng = max(maxLng, p.longitude)
        }
        return (minLat, minLng, maxLat, maxLng)
    }

    /// Ray-casting: 점(point)이 폴리곤 내부인지 판정 (x=lng, y=lat)
    private func containsPoint(_ point: CLLocationCoordinate2D, in polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        let x = point.longitude
        let y = point.latitude

        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            // 수평 레이(y 기준)와 변이 교차하는지
            let denom = (yj - yi) == 0 ? 1e-12 : (yj - yi)
            let intersects = ((yi > y) != (yj > y)) &&
            (x < (xj - xi) * (y - yi) / denom + xi)

            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }

    /// 닫힌 폴리곤 내부에 들어가는 모든 셀 id를 계산한다.
    /// 구현: 폴리곤 바운딩 박스를 gridSize 격자로 훑고, 각 셀 중심점이 폴리곤 내부면 점령
    private func capturedCells(in polygon: [CLLocationCoordinate2D]) -> Set<String> {
        guard let b = polygonBounds(polygon) else { return [] }

        // 스캔 시작/끝을 gridSize 정렬로 맞춤
        let startLat = floor(b.minLat / gridSize) * gridSize
        let startLng = floor(b.minLng / gridSize) * gridSize
        let endLat = floor(b.maxLat / gridSize) * gridSize
        let endLng = floor(b.maxLng / gridSize) * gridSize

        var result: Set<String> = []
        var lat = startLat
        while lat <= endLat {
            var lng = startLng
            while lng <= endLng {
                let center = cellCenter(lat: lat, lng: lng)
                if containsPoint(center, in: polygon) {
                    result.insert(cellId(lat: lat, lng: lng))
                }
                lng += gridSize
            }
            lat += gridSize
        }
        return result
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
            #if DEBUG
            if useMockRoute {
                // mock 모드에서는 실제 GPS 업데이트를 켜지 않음
                return
            }
            #endif
            clManager.startUpdatingLocation()
        }
    }
    
    /// GPS에서 “새 위치”가 들어올 때마다 호출되는 delegate.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        #if DEBUG
        if useMockRoute {
            // mock 모드에서는 실제 GPS 위치 업데이트를 무시
            return
        }
        #endif
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
