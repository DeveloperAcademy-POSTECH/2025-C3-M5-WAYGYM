import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth
import CoreLocation

private enum FirestorePaths {
    static let userRunsRoot = "RunRecordModels"        // top-level collection
    static let perUserRunRecords = "runRecords"           // subcollection under each uid
}

// MARK: - 좌표 쌍 구조체
struct CoordinatePair: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct CoordinatePairWithGroup: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let groupId: Int
}

// MARK: - 데이터 모델
struct RunRecordModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String? // Firestore 문서 ID
    let distance: Double // 이동 거리 (미터)
    let startTime: Date // 시작 시간
    let endTime: Date? // 종료 시간
    var duration: TimeInterval {
        guard let end = endTime else {return 0}
        return end.timeIntervalSince(startTime)
    }
    
    let routeImage: String? // Firebase Storage 이미지 URL
    let coordinates: [CoordinatePair]  // 경로 좌표 [[latitude, longitude]] - 사용자의 전체 경로
    let capturedAreas: [CoordinatePairWithGroup]  // 면적을 형성한 좌표들 (groupId로 도형 구분)
    let capturedAreaValue: Int // 유저가 차지한 면적 (숫자 데이터)
    
    enum CodingKeys: String, CodingKey {
        case id
        case distance
        case startTime = "start_time"
        case endTime = "end_time"
        case routeImage
        case coordinates
        case capturedAreas = "captured_areas"
        case capturedAreaValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        distance = try container.decode(Double.self, forKey: .distance)
        // stepCount = try container.decode(Double.self, forKey: .stepCount)
        // caloriesBurned = try container.decode(Double.self, forKey: .caloriesBurned)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        routeImage = try container.decodeIfPresent(String.self, forKey: .routeImage)
        coordinates = try container.decode([CoordinatePair].self, forKey: .coordinates)
        capturedAreas = try container.decode([CoordinatePairWithGroup].self, forKey: .capturedAreas)
        capturedAreaValue = try container.decodeIfPresent(Int.self, forKey: .capturedAreaValue) ?? 0
    }
    
    init(id: String? = nil,
         distance: Double,
//         stepCount: Double,
//         caloriesBurned: Double,
         startTime: Date,
         endTime: Date?,
         routeImage: String?,
         coordinates: [CoordinatePair],
         capturedAreas: [CoordinatePairWithGroup],
         capturedAreaValue: Int) {
        self.id = id
        self.distance = distance
        // self.stepCount = stepCount
        // self.caloriesBurned = caloriesBurned
        self.startTime = startTime
        self.endTime = endTime
        self.routeImage = routeImage
        self.coordinates = coordinates
        self.capturedAreas = capturedAreas
        self.capturedAreaValue = capturedAreaValue
    }
    
    // 좌표를 CLLocationCoordinate2D로 변환
    var coordinateList: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
    
    static func makeDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: dateString) ?? Date()
    }
}

// Run Card View
struct RunCardModel: Identifiable {
    let id: String
    let routeImageURL: URL?
    let distance: Double
    let duration: TimeInterval
    let calories: Double
    let capturedArea: Double
    let startTime: Date
}

extension RunCardModel {
    static func fromFirestoreDocument(doc: QueryDocumentSnapshot) throws -> RunCardModel {
            let data = doc.data()
            guard
                let s = (data["start_time"] as? Timestamp)?.dateValue(),
                let e = (data["end_time"]   as? Timestamp)?.dateValue()
            else { throw NSError(domain: "time_missing", code: 0) }

            let duration = e.timeIntervalSince(s)
            let calories = duration / 60 * 7.4
            let routeURL = (data["routeImage"] as? String).flatMap(URL.init(string:))
            let area: Double = {
                if let v = data["capturedAreaValue"] as? Double { return v }
                if let v = data["capturedAreaValue"] as? Int { return Double(v) }
                return 0
            }()

            return RunCardModel(
                id: doc.documentID,
                routeImageURL: routeURL,
                distance: (data["distance"] as? Double) ?? 0,
                duration: duration,
                calories: calories,
                capturedArea: area,
                startTime: s
            )
        }
    
    static func fetchRunSummary(db: Firestore = Firestore.firestore()) async throws -> [RunCardModel] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "auth_missing_uid", code: 0)
        }
        let snap = try await db
            .collection(FirestorePaths.userRunsRoot)
            .document(uid)
            .collection(FirestorePaths.perUserRunRecords)
            .order(by: "start_time", descending: true)
            .getDocuments()
        return try snap.documents.map { try RunCardModel.fromFirestoreDocument(doc: $0) }
    }
}

// Big Detail View
struct RunDetailModel: Identifiable {
    let id: String
    let routeImageURL: URL?
    let distance: Double
    let duration: TimeInterval
    let calories: Double
    let capturedArea: Double
    let startTime: Date
    let coordinates: [CoordinatePair]
    let capturedAreas: [CoordinatePairWithGroup]
}

extension RunDetailModel {
    static func fromFirestoreData(id: String, data: [String: Any]) throws -> RunDetailModel {
        let start = (data["start_time"] as? Timestamp)?.dateValue()
        let end   = (data["end_time"]   as? Timestamp)?.dateValue()
        guard let s = start, let e = end else { throw NSError(domain: "time_missing", code: 0) }

        let duration = e.timeIntervalSince(s)
        let calories = duration / 60 * 7.4
        let routeURL = (data["routeImage"] as? String).flatMap(URL.init(string:))
        let area: Double = {
            if let v = data["capturedAreaValue"] as? Double { return v }
            if let v = data["capturedAreaValue"] as? Int { return Double(v) }
            return 0
        }()

        let coordinatesArr = (data["coordinates"] as? [Any]) ?? []
        let coordinates: [CoordinatePair] = coordinatesArr.compactMap {
            guard let d = $0 as? [String: Any],
                  let lat = d["latitude"] as? Double,
                  let lon = d["longitude"] as? Double else { return nil }
            return CoordinatePair(latitude: lat, longitude: lon)
        }

        let capturedAreasArr = (data["captured_areas"] as? [Any]) ?? []
        let capturedAreas: [CoordinatePairWithGroup] = capturedAreasArr.compactMap {
            guard let d = $0 as? [String: Any],
                  let lat = d["latitude"] as? Double,
                  let lon = d["longitude"] as? Double,
                  let gid = d["groupId"] as? Int else { return nil }
            return CoordinatePairWithGroup(latitude: lat, longitude: lon, groupId: gid)
        }

        return RunDetailModel(
            id: id,
            routeImageURL: routeURL,
            distance: (data["distance"] as? Double) ?? 0,
            duration: duration,
            calories: calories,
            capturedArea: area,
            startTime: s,
            coordinates: coordinates,
            capturedAreas: capturedAreas
        )
    }
    
    static func fetch(byId id: String, db: Firestore = Firestore.firestore()) async throws -> RunDetailModel {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "auth_missing_uid", code: 0)
        }
        let doc = try await db
            .collection(FirestorePaths.userRunsRoot)
            .document(uid)
            .collection(FirestorePaths.perUserRunRecords)
            .document(id)
            .getDocument()
        guard let data = doc.data() else { throw NSError(domain: "no_doc", code: 0) }
        return try RunDetailModel.fromFirestoreData(id: doc.documentID, data: data)
    }
}
