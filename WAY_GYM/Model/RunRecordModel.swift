import Foundation

struct CoordinatePair: Codable {
    var latitude: Double
    var longitude: Double
}

struct RunRecordModel: Identifiable, Codable {
    let id: UUID
    
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval { // 걸은 시간
        guard let end = endTime else {return 0}
        return end.timeIntervalSince(startTime)
    }
    
    var totalDistance: Double = 0 // 총 걸은 거리
    var caloriesBurned: Double = 0 // 칼로리
    var steps: Int = 0 // (optional) 걸음수
    
    var routeImage: String? = nil // 유저가 이동한 경로 전체 이미지(면적 유무와 무관). 파일명 또는 url
    var capturedAreas: [[CoordinatePair]] = [] // 유저가 차지한 면적(좌표 데이터)
    var capturedAreaValue: Double = 0 // 유저가 차지한 면적 (숫자 데이터)
    
    static func makeDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: dateString) ?? Date()
    }
}


