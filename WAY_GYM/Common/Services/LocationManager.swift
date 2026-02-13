import Foundation
import MapKit
import CoreLocation
import HealthKit
import FirebaseStorage
import Photos
import FirebaseCore
import FirebaseAuth

final class ColoredPolygon: MKPolygon {
    var isMine: Bool = true
}

// - CLLocationManager에게 사용자 위치를 받아서, 앱에서 쓰기 좋은 상태(@Published)로 가공한다.
// - 러닝(시뮬레이션) 중: 경로 좌표를 누적하고 폴리라인/폴리곤 오버레이 데이터를 만든다.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    weak var runRecordStore: RunRecordStore?
    var userStore: UserStore?
    
    private let clManager = CLLocationManager() /// GPS 위치를 받아오는 시스템 객체
    @Published var region = MKCoordinateRegion() // 지도가 보여줄 영역 (센터+줌)
    @Published var currentLocation: CLLocationCoordinate2D? // 현재 위치 표시하는 캐릭터 좌표
    
    @Published var polylines: [MKPolyline] = []
    @Published var polygons: [MKPolygon] = []

    /// 최초로 위치를 받았을 때(또는 currentLocation이 처음 잡혔을 때) 1회만 지도를 그 위치로 센터링하기 위한 플래그
    private var didCenterOnFirstLocation = false
    
    @Published var isSimulating = false /// 러닝(경로 추적) 중인지 여부. (UI 표시 상태가 아니라, 좌표 누적/경로 생성 로직을 켤지 말지 결정)
    
    /// 서버에서 가져오거나 보낼 런닝 기록 모델
    @Published var runRecord: RunRecord?
    @Published var runRecordList: [RunRecord] = [] /// 서버에서 받아온 모든 런닝 기록
    
    private var coordinates: [CLLocationCoordinate2D] = [] /// 러닝 중 누적된 좌표 원본 (모든 이동 좌표)
    /// 폴리곤을 더 세부 데이터로 저장하는 용도
    @Published var capturedAreas: [CoordinatePairWithGroup] = [] // 닫힌 영역의 꼭짓점들을 모아서 저장한 배열
    @Published var isAreaActive = false
    
    private let gridSize: Double = 0.0005 // 셀 한 변 크기
    @Published private(set) var capturedCellIds: Set<String> = [] /// 닫힌 영역 내, 사용자가 획득한 셀의 좌표
    /// 지도에 이미 그려둔(overlay로 추가한) 셀 id들 (중복 overlay 추가 방지)
    private var renderedCellIds: Set<String> = []
    
    private var simulationTimer: Timer? /// 1초마다 위치를 읽어오는 타이머

    // MARK: - DEBUG Mock Route (방구석 개발러용)
    #if DEBUG
    /// true면 실제 GPS 대신 mock 좌표로 이동한다. (필요 없으면 false)
    private var useMockRoute: Bool = true
    private var mockRoute: [CLLocationCoordinate2D] = []
    private var mockRouteIndex: Int = 0
    private var mockDriftStep: Int = 0

    /// 재현 가능한(시드 기반) 랜덤을 위한 RNG
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) {
            self.state = seed == 0 ? 0xdeadbeef : seed
        }
        mutating func next() -> UInt64 {
            // LCG (simple, fast)
            state = state &* 6364136223846793005 &+ 1
            return state
        }
    }

    /// 기준 좌표 주변으로 "되돌아가며 교차"하는 경로를 만든다.
    /// - 목표: gridSize(0.001) 셀을 실제로 덮을 수 있을 만큼(> 0.001도) 큰 루프를 만든다.
    /// - 단, 1초마다 이동할 때 speed limit(5.56m/s)을 넘지 않도록 한 step은 약 5~6m로 유지.
    private func buildMockRoute(around base: CLLocationCoordinate2D, seed: UInt64) -> [CLLocationCoordinate2D] {
        // ✅ 사람이 실제로 달리는 것처럼 "크게 빙 둘러" 한 바퀴 도는 루프를 만든다.
        // - 지그재그/왕복을 줄이고, 부드러운 타원(oval) 궤적으로 이동
        // - 마지막에 시작점 근처로 자연스럽게 복귀하면서 폐구간(교차) 트리거

        var rng = SeededGenerator(seed: seed)
        func rand(_ range: ClosedRange<Double>) -> Double {
            Double.random(in: range, using: &rng)
        }

        // ✅ 15초 내 폐구간을 만들기 위해, "큰 원"보단 "중간 원"을 더 적은 포인트로 크게 점프한다.
        // (위도/경도 m 환산 차이는 디버그 목적엔 충분)
        let radiusLat = rand(0.0018...0.0032)   // 대략 200~350m
        let radiusLng = rand(0.0022...0.0038)   // 대략 200~350m(한국 위도 기준)

        // 매번 약간 다른 방향으로
        let phase = rand(0...Double.pi * 2)

        // ✅ 1초에 1포인트 소비하므로, 전체 길이를 ~15초로 맞춘다.
        // 타원 1바퀴를 10~13포인트로 그리면 1초당 이동거리가 커져서 "더 멀리" 움직이는 느낌이 난다.
        let points = Int(rand(10...13))

        // 흔들림(너무 크면 왕복처럼 보이니 아주 작게)
        let jitterLat = gridSize * rand(0.02...0.08)
        let jitterLng = gridSize * rand(0.02...0.08)

        var route: [CLLocationCoordinate2D] = []
        route.reserveCapacity(points + 20)

        // 1) 타원 루프 1바퀴
        for i in 0..<points {
            let t = (Double(i) / Double(points)) * (Double.pi * 2) + phase

            // 약한 비틀림(단조로움 방지, but 과하게 튀지 않게)
            let wobble = sin(t * 2) * rand(-0.08...0.08)

            let lat = base.latitude + sin(t + wobble) * radiusLat + rand(-jitterLat...jitterLat)
            let lng = base.longitude + cos(t - wobble) * radiusLng + rand(-jitterLng...jitterLng)

            route.append(.init(latitude: lat, longitude: lng))
        }

        // 2) 시작점 근처로 자연스럽게 닫히도록 tail 추가 (교차 트리거 확률↑)
        if let first = route.first, let last = route.last {
            // 닫힘을 보장하기 위한 짧은 tail (전체 15초 목표)
            let tailSteps = Int(rand(2...3))
            var pos = last
            for _ in 0..<tailSteps {
                let dLat = first.latitude - pos.latitude
                let dLng = first.longitude - pos.longitude
                pos = .init(
                    latitude: pos.latitude + dLat * 0.35 + rand(-jitterLat...jitterLat),
                    longitude: pos.longitude + dLng * 0.35 + rand(-jitterLng...jitterLng)
                )
                route.append(pos)
            }
            // 확실히 닫기
            route.append(first)
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

            // 매 사이클마다 기준점을 랜덤으로 살짝 이동(같은 구역만 도는 느낌 제거)
            let driftLat = Double.random(in: -0.0030...0.0030) // 대략 -300m ~ +300m
            let driftLng = Double.random(in: -0.0030...0.0030)

            let base = CLLocationCoordinate2D(latitude: coord.latitude + driftLat, longitude: coord.longitude + driftLng)
            mockRoute = buildMockRoute(around: base, seed: UInt64(mockDriftStep) ^ UInt64(Date().timeIntervalSince1970))
            print("🧪 Mock route rebuilt. driftStep=\(mockDriftStep) points=\(mockRoute.count)")
        }

        return coord
    }
    #endif
    private var lastIntersectionIndex: Int? /// 폴리곤이 만들어진 지점 이후부터 새 선을 만들기 위한 기준 인덱스

    private var startTime: Date?
    private var endTime: Date?
    
    private let storage = Storage.storage()
    private let runRecordRepository: RunRecordRepositoryProtocol = RunRecordRepository()
    private let duoBattleRepository: DuoBattleRepositoryProtocol = DuoBattleRepository()

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

        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 사용자가 없습니다. RunRecord 저장 중단")
            return
        }

        let routeEncoded = PolylineEncoder.encode(coordinates)
        let routeFrame = computeRouteFrame(from: coordinates)
        let activeDuoWorldId = userStore?.profile?.activeDuoWorldId
        let runType: RunRecordType = activeDuoWorldId == nil ? .solo : .duo
        print("🏃 saveRunRecord | userStoreNil=\(userStore == nil), activeDuoWorldId=\(String(describing: activeDuoWorldId)) runType=\(runType.rawValue)")

        let newData = RunRecord(
            id: nil,
            type: runType,
            activeDuoWorldId: activeDuoWorldId,
            startTime: start,
            endTime: endTime,
            distanceM: calculateTotalDistance(),
            routeEncoded: routeEncoded,
            capturedCellIds: Array(self.capturedCellIds),
            routeFrame: routeFrame
        )

        Task {
            do {
                let runId = try await runRecordRepository.saveRunRecord(uid: uid, record: newData)
                print("Firestore에 RunRecord 저장 성공 (uid=\(uid), runId=\(runId))")
                if let worldId = activeDuoWorldId, runType == .duo {
                    let capturedAt = newData.endTime ?? newData.startTime
                    try await runRecordRepository.saveWorldCells(
                        worldId: worldId,
                        ownerUid: uid,
                        runId: runId,
                        cellIds: newData.capturedCellIds,
                        lastCapturedAt: capturedAt
                    )
                }
                await MainActor.run {
                    self.runRecord = newData
                }
                if let runRecordStore {
                    await runRecordStore.refresh()
                }
            } catch {
                print("Firestore 저장 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 서버(runRecordStore)에서 런닝 기록 가져오기
    func fetchRunRecordsFromFirestore() {
        let records = runRecordStore?.runRecords ?? []
        runRecordList = records
        runRecord = records.first
        polylines.removeAll()
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
        capturedCellIds.removeAll()
        renderedCellIds.removeAll()
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
            self.mockRoute = buildMockRoute(around: base, seed: UInt64(Date().timeIntervalSince1970))
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
                    self.centerMapOnceOnFirstLocationIfNeeded(mock)
                    self.centerMap(on: mock)
                }
                return
            }
            #endif

            if let lastLocation = self.clManager.location {
                self.updateRunCoordinateIfValid(newCoordinate: lastLocation.coordinate)
                self.currentLocation = lastLocation.coordinate
                self.centerMapOnceOnFirstLocationIfNeeded(lastLocation.coordinate)
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
            self.renderedCellIds.removeAll()
        }
        coordinates.removeAll()
        lastIntersectionIndex = nil
        didCenterOnFirstLocation = false
    }
    
    /// 런닝 시: 좌표가 유효한지 확인
    private func updateRunCoordinateIfValid(newCoordinate: CLLocationCoordinate2D) {
        #if DEBUG
        // 🧪 Mock route는 테스트 편의상 큰 step을 쓰므로, 유효성 검사를 잠깐 우회
        if useMockRoute {
            coordinates.append(newCoordinate)
            drawPolylines()
            checkAndDrawPolygon()
            centerMap(on: newCoordinate)
            return
        }
        #endif

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

                    // ✅ 폴리곤 내부 셀 점령 계산 (하지만 '폐구간 자체'는 채우지 않고, 셀(사각형)만 색칠한다)
                    let newlyCaptured = capturedCells(in: polygonCoordinates)
                    let diff = newlyCaptured.subtracting(self.renderedCellIds)

                    self.capturedCellIds.formUnion(newlyCaptured)

                    // 새로 점령된 셀만 overlay(사각형 polygon)로 추가
                    for id in diff {
                        guard let origin = parseCellId(id) else { continue }
                        let cellPolygon = makeCellPolygon(originLat: origin.lat, originLng: origin.lng)
                        self.polygons.append(cellPolygon)
                    }
                    self.renderedCellIds.formUnion(diff)

                    print("🟩 Captured cells +\(diff.count) (total=\(self.capturedCellIds.count))")
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
    
    // MARK: - 루트 인코딩
    /// routeFrame: [minLat, minLng, maxLat, maxLng]
    private func computeRouteFrame(from coords: [CLLocationCoordinate2D]) -> [Double] {
        guard let first = coords.first else { return [0, 0, 0, 0] }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLng = first.longitude
        var maxLng = first.longitude

        for c in coords.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude)
            maxLng = max(maxLng, c.longitude)
        }
        return [minLat, minLng, maxLat, maxLng]
    }

    /// Google Encoded Polyline Algorithm Format (1e5)
    private enum PolylineEncoder {
        static func encode(_ coords: [CLLocationCoordinate2D]) -> String {
            guard !coords.isEmpty else { return "" }

            var output = ""
            var lastLat = 0
            var lastLng = 0

            for c in coords {
                let lat = Int((c.latitude * 1e5).rounded())
                let lng = Int((c.longitude * 1e5).rounded())

                let dLat = lat - lastLat
                let dLng = lng - lastLng

                output.append(encodeValue(dLat))
                output.append(encodeValue(dLng))

                lastLat = lat
                lastLng = lng
            }

            return output
        }

        private static func encodeValue(_ value: Int) -> String {
            var v = value
            v = v << 1
            if value < 0 { v = ~v }

            var encoded = ""
            while v >= 0x20 {
                let char = (0x20 | (v & 0x1f)) + 63
                encoded.append(Character(UnicodeScalar(char)!))
                v >>= 5
            }
            let lastChar = v + 63
            encoded.append(Character(UnicodeScalar(lastChar)!))
            return encoded
        }
    }
    
    // MARK: - 사용자가 획득한 땅 (셀)
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

    /// 셀이 "완전히" 폴리곤 내부인지 확인하기 위한 4 코너(모서리) 좌표를 만든다.
    /// - floating error로 경계선 위 판정이 흔들릴 수 있으니, 아주 작은 epsilon만큼 안쪽으로 inset한다.
    private func cellInsetCorners(lat: Double, lng: Double) -> [CLLocationCoordinate2D] {
        let eps = gridSize * 0.001
        let minLat = lat + eps
        let minLng = lng + eps
        let maxLat = (lat + gridSize) - eps
        let maxLng = (lng + gridSize) - eps

        return [
            .init(latitude: minLat, longitude: minLng),
            .init(latitude: minLat, longitude: maxLng),
            .init(latitude: maxLat, longitude: maxLng),
            .init(latitude: maxLat, longitude: minLng)
        ]
    }

    /// 셀의 4 코너가 모두 폴리곤 내부면, 셀은 "온전히" 내부에 있다고 판단한다.
    private func isCellFullyInsidePolygon(cellLat: Double, cellLng: Double, polygon: [CLLocationCoordinate2D]) -> Bool {
        let corners = cellInsetCorners(lat: cellLat, lng: cellLng)
        for c in corners {
            if !containsPoint(c, in: polygon) { return false }
        }
        return true
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
    /// 구현: 폴리곤 바운딩 박스를 gridSize 격자로 훑고, 각 셀의 4 코너가 폴리곤 내부면 점령
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
                if isCellFullyInsidePolygon(cellLat: lat, cellLng: lng, polygon: polygon) {
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

        guard let location = clManager.location else {
            print("⏳ No current location available yet.")
            clManager.startUpdatingLocation()
            return
        }

        let coord = location.coordinate
        print("📍 Current location available: \(coord)")

        DispatchQueue.main.async {
            let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            self.region = MKCoordinateRegion(center: coord, span: span)
            self.currentLocation = coord
        }
    }
    
    /// currentLocation이 "처음" 잡히는 순간에만 region을 해당 위치로 세팅한다.
    /// - 사용자가 이후에 줌/이동을 했다면 그 상태를 존중하기 위해 1회만 실행.
    private func centerMapOnceOnFirstLocationIfNeeded(_ coordinate: CLLocationCoordinate2D) {
        guard !didCenterOnFirstLocation else { return }
        didCenterOnFirstLocation = true

        // 최초 진입에서는 span이 0일 수 있으니 안전한 기본 span으로 세팅
        let fallbackSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        region = MKCoordinateRegion(center: coordinate, span: fallbackSpan)
    }

    /// 이 좌표를 중심으로 지도 화면을 이동함
    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        // ✅ center만 따라가고, 사용자가 줌인/줌아웃한 span은 유지한다.
        let currentSpan = region.span
        let fallbackSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)

        let spanToUse: MKCoordinateSpan
        if currentSpan.latitudeDelta > 0, currentSpan.longitudeDelta > 0 {
            spanToUse = currentSpan
        } else {
            spanToUse = fallbackSpan
        }

        region = MKCoordinateRegion(center: coordinate, span: spanToUse)
    }
    
    /// 사용자의 전체 런닝 기록 중 "점유한 셀"을 지도에 표시하기 위한 MKPolygon 배열을 만든다.
    /// - records 안의 모든 capturedCellIds를 합쳐서, 각 셀을 사각형 폴리곤으로 변환한다.
    func loadCapturedPolygons(from records: [RunRecord]) {
        let shouldFilterSoloOnly = userStore?.profile?.activeDuoWorldId == nil
        let activeDuoWorldId = userStore?.profile?.activeDuoWorldId
        let filteredRecords = shouldFilterSoloOnly
            ? records.filter { $0.type == .solo }
            : records

        if let activeDuoWorldId {
            guard let uid = Auth.auth().currentUser?.uid else {
                self.polygons = []
                return
            }

            Task {
                var result: [MKPolygon] = []
                let cells = (try? await duoBattleRepository.fetchWorldCells(worldId: activeDuoWorldId)) ?? []
                result.reserveCapacity(cells.count)

                for cell in cells {
                    guard let cellId = cell.id else { continue }
                    guard let origin = parseCellId(cellId) else { continue }
                    let isMine = cell.ownerUid == uid
                    let polygon = makeCellPolygon(originLat: origin.lat, originLng: origin.lng, isMine: isMine)
                    result.append(polygon)
                }

                await MainActor.run {
                    self.polygons = result
                }
            }
            return
        }

        // 1) 모든 기록의 capturedCellIds 합치기
        var allCellIds: Set<String> = []
        for r in filteredRecords {
            allCellIds.formUnion(r.capturedCellIds)
        }

        // 2) 각 셀을 사각형 MKPolygon으로 변환
        var result: [MKPolygon] = []
        result.reserveCapacity(allCellIds.count)

        for id in allCellIds {
            guard let origin = parseCellId(id) else { continue }
            let polygon = makeCellPolygon(originLat: origin.lat, originLng: origin.lng)
            result.append(polygon)
        }

        self.polygons = result
    }

    /// "lat,lng" 형태의 셀 id를 파싱
    private func parseCellId(_ id: String) -> (lat: Double, lng: Double)? {
        let parts = id.split(separator: ",", omittingEmptySubsequences: true)
        guard parts.count == 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let lng = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return (lat, lng)
    }

    /// 셀의 원점(lat,lng)과 gridSize를 이용해 셀 사각형 폴리곤을 만든다.
    private func makeCellPolygon(originLat: Double, originLng: Double, isMine: Bool? = nil) -> MKPolygon {
        let minLat = originLat
        let minLng = originLng
        let maxLat = originLat + gridSize
        let maxLng = originLng + gridSize

        let coords: [CLLocationCoordinate2D] = [
            .init(latitude: minLat, longitude: minLng),
            .init(latitude: minLat, longitude: maxLng),
            .init(latitude: maxLat, longitude: maxLng),
            .init(latitude: maxLat, longitude: minLng),
            .init(latitude: minLat, longitude: minLng) // close
        ]

        if let isMine {
            let polygon = ColoredPolygon(coordinates: coords, count: coords.count)
            polygon.isMine = isMine
            return polygon
        }

        return MKPolygon(coordinates: coords, count: coords.count)
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
        centerMapOnceOnFirstLocationIfNeeded(newCoordinate)
        
        // 시뮬레이션 중일 때만 위치 업데이트 및 유효성 검사 수행
        if isSimulating {
            updateRunCoordinateIfValid(newCoordinate: newCoordinate)
        }
        centerMap(on: newCoordinate)
    }
}
