import Foundation
import MapKit
import CoreLocation
import HealthKit
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Photos
import FirebaseCore

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion()
    @Published var polylines: [MKPolyline] = []
    @Published var polygons: [MKPolygon] = []
    @Published var isSimulating = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var runRecord: RunRecordModels?
    @Published var runRecordList: [RunRecordModels] = []
    @Published var capturedAreas: [CoordinatePairWithGroup] = []
    @Published var isAreaActive = false
    
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
    private var firestoreListener: ListenerRegistration?

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.requestWhenInUseAuthorization()
    }

    private func updateRunRecord(imageURL: String? = nil) {
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
                    if !self.isAreaActive {
                        self.polylines = dataList.flatMap { record in
                            let coords = record.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                            return [MKPolyline(coordinates: coords, count: coords.count)]
                        }
                        print("Polylines loaded: \(self.polylines.count)")
                    } else {
                        self.polylines.removeAll()
                        print("Polylines cleared due to isAreaActive")
                    }
                }
            }
    }

    func startSimulation() {
        guard clManager.authorizationStatus == .authorizedWhenInUse || clManager.authorizationStatus == .authorizedAlways else {
            clManager.requestWhenInUseAuthorization()
            return
        }
        guard !isSimulating else {
            print("🛑 이미 시뮬레이션 중이므로 실행 안 함")
            return
        }
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
    
    private func updateRegion(coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }
    
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
    
    func loadCapturedPolygons(from records: [RunRecordModels]) {
        var result: [MKPolygon] = []
        for record in records {
            let grouped = Dictionary(grouping: record.capturedAreas, by: { $0.groupId })
            for (_, group) in grouped {
                let coords = group.map {
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
                } else {
                    print("유효하지 않은 폴리곤 좌표: \(coords)")
                }
            }
        }
        self.polygons = result
        if isAreaActive {
            self.polylines.removeAll()
            print("Polylines cleared in loadCapturedPolygons")
        }
    }
    
    private func isValidCoordinate(_ newCoordinate: CLLocationCoordinate2D, lastCoordinate: CLLocationCoordinate2D?) -> Bool {
        guard newCoordinate.latitude >= -90 && newCoordinate.latitude <= 90 &&
                newCoordinate.longitude >= -180 && newCoordinate.longitude <= 180 else {
            print("유효하지 않은 좌표 범위: \(newCoordinate)")
            return false
        }
        
        guard let last = lastCoordinate else { return true }
        
        let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
        let distance = lastLocation.distance(from: newLocation)
        guard distance < 500 else {
            print("비현실적 거리 감지: \(distance)m")
            return false
        }
        let speed = distance / 1.0
        guard speed < 13.89 else {
            print("비현실적 속도 감지: \(speed)m/s")
            return false
        }
        return true
    }
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            clManager.startUpdatingLocation()
        }
    }
    
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
        if isSimulating {
            updateCoordinates(newCoordinate: newCoordinate)
        }
        updateRegion(coordinate: newCoordinate)
    }
}
