import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import CoreLocation

// MARK: - 좌표 쌍 구조체
struct CoordinatePair: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - 데이터 모델
struct RunRecordModels: Identifiable, Codable {
    @DocumentID var id: String? // Firestore 문서 ID
    let distance: Double // 이동 거리 (미터)
    let stepCount: Double // 걸음 수
    let caloriesBurned: Double // 소모 칼로리 (kcal)
    
    let startTime: Date // 시작 시간
    let endTime: Date? // 종료 시간 (선택적)
    var duration: TimeInterval {
        guard let end = endTime else {return 0}
        return end.timeIntervalSince(startTime)
    }
    
    let routeImage: String? // Firebase Storage 이미지 URL (선택적)
    let coordinates: [[Double]] // 경로 좌표 [[latitude, longitude]]
    let capturedAreas: [[CoordinatePair]] // 캡처된 도형 좌표
    let capturedAreaValue: Double // 유저가 차지한 면적 (숫자 데이터)
    
    enum CodingKeys: String, CodingKey {
        case id
        case distance
        case stepCount = "step_count"
        case caloriesBurned = "calories_burned"
        case startTime = "start_time"
        case endTime = "end_time"
        case routeImage = "route_image"
        case coordinates
        case capturedAreas = "captured_areas"
        case capturedAreaValue = "captured_area_value"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        distance = try container.decode(Double.self, forKey: .distance)
        stepCount = try container.decode(Double.self, forKey: .stepCount)
        caloriesBurned = try container.decode(Double.self, forKey: .caloriesBurned)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        routeImage = try container.decodeIfPresent(String.self, forKey: .routeImage)
        coordinates = try container.decode([[Double]].self, forKey: .coordinates)
        capturedAreas = try container.decode([[CoordinatePair]].self, forKey: .capturedAreas)
        capturedAreaValue = try container.decode(Double.self, forKey: .capturedAreaValue)
    }
    
    init(id: String? = nil,
         distance: Double,
         stepCount: Double,
         caloriesBurned: Double,
         startTime: Date,
         endTime: Date?,
         routeImage: String?,
         coordinates: [[Double]],
         capturedAreas: [[CoordinatePair]],
         capturedAreaValue: Double) {
        self.id = id
        self.distance = distance
        self.stepCount = stepCount
        self.caloriesBurned = caloriesBurned
        self.startTime = startTime
        self.endTime = endTime
        self.routeImage = routeImage
        self.coordinates = coordinates
        self.capturedAreas = capturedAreas
        self.capturedAreaValue = capturedAreaValue
    }
    
    // 좌표를 CLLocationCoordinate2D로 변환
    var coordinateList: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }
    
    static func makeDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: dateString) ?? Date()
    }
}


//struct CoordinatePair: Codable {
//    var latitude: Double
//    var longitude: Double
//}
//
//struct RunRecordModel: Identifiable, Codable {
//    let id: UUID
//    
//    var startTime: Date
//    var endTime: Date?
//    var duration: TimeInterval { // 걸은 시간
//        guard let end = endTime else {return 0}
//        return end.timeIntervalSince(startTime)
//    }
//    
//    var totalDistance: Double = 0 // 총 걸은 거리
//    var caloriesBurned: Double = 0 // 칼로리
//    var steps: Int = 0 // (optional) 걸음수
//    
//    var routeImage: String? = nil // 유저가 이동한 경로 전체 이미지(면적 유무와 무관). 파일명 또는 url
//    var capturedAreas: [[CoordinatePair]] = [] // 유저가 차지한 면적(좌표 데이터)
//    var capturedAreaValue: Double = 0 // 유저가 차지한 면적 (숫자 데이터)
//    
//    static func makeDate(_ dateString: String) -> Date {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy.MM.dd HH:mm"
//        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
//        return formatter.date(from: dateString) ?? Date()
//    }
//}
//
//
