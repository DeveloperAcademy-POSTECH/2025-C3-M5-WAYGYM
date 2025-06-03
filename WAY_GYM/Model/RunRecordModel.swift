import Foundation

struct CoordinatePair: Codable {
    var latitude: Double
    var longitude: Double
}

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
//    // yyyy.mm.dd 00:00시로 등록된
//    static func makeDate(_ dateString: String) -> Date {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy.MM.dd HH:mm"
//        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
//        return formatter.date(from: dateString) ?? Date()
//    }
//    
//}

// 레오
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
        case duration
        case imageURL = "image_url"
        case coordinates
        case capturedAreas = "captured_areas"
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


