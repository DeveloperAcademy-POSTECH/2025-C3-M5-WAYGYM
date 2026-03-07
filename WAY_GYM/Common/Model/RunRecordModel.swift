import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import CoreLocation

// MARK: - 데이터 모델
struct RunRecord: Identifiable, Codable, Equatable {
    @DocumentID var id: String? // Firestore 문서 ID
    let type: RunRecordType?
    let activeDuoWorldId: String?
    let startTime: Date
    let endTime: Date?
    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
    let distanceM: Double
    let routeEncoded: String
    let capturedCellIds: [String] /// 이 런으로 획득한 셀 id들 ("lat,lng")
    let routeFrame: [Double] /// [minLat, minLng, maxLat, maxLng]

    enum CodingKeys: String, CodingKey {
        case type
        case activeDuoWorldId = "active_duo_world_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case distanceM = "distance_m"
        case routeEncoded = "route_encoded"
        case capturedCellIds = "captured_cell_ids"
        case routeFrame = "route_frame"
    }

    enum Field: String, FirestoreFieldKey {
        case type
        case activeDuoWorldId = "active_duo_world_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case distanceM = "distance_m"
        case routeEncoded = "route_encoded"
        case capturedCellIds = "captured_cell_ids"
        case routeFrame = "route_frame"
    }

    enum Collection: String, FirestoreCollectionKey {
        case runs = "runs"
    }

    static func collectionPath(uid: String) -> FirestoreCollectionPath {
        FirestoreCollectionPath(
            rawValue: "\(FirestoreCollection.runRecords.key)/\(uid)/\(Collection.runs.key)"
        )
    }

//    init(from decoder: Decoder) throws {
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        if let docId = decoder.userInfo[FirestoreDecodingUserInfoKey.documentID] as? String {
//            id = docId
//        }
//        startTime = try c.decode(Date.self, forKey: .startTime)
//        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
//        distanceM = try c.decodeIfPresent(Double.self, forKey: .distanceM) ?? 0
//        routeEncoded = try c.decodeIfPresent(String.self, forKey: .routeEncoded) ?? ""
//        capturedCellIds = (try? c.decode([String].self, forKey: .capturedCellIds)) ?? []
//        routeFrame = (try? c.decode([Double].self, forKey: .routeFrame)) ?? [0, 0, 0, 0]
//    }

    init(
        id: String? = nil,
        type: RunRecordType? = nil,
        activeDuoWorldId: String? = nil,
        startTime: Date,
        endTime: Date?,
        distanceM: Double,
        routeEncoded: String,
        capturedCellIds: [String],
        routeFrame: [Double]
    ) {
        self.id = id
        self.type = type
        self.activeDuoWorldId = activeDuoWorldId
        self.startTime = startTime
        self.endTime = endTime
        self.distanceM = distanceM
        self.routeEncoded = routeEncoded
        self.capturedCellIds = capturedCellIds
        self.routeFrame = routeFrame
    }

    static func makeDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: dateString) ?? Date()
    }
}

enum RunRecordType: String, Codable {
    case solo
    case duo
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
