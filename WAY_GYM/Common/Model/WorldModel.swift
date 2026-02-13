import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct WorldRequest: Codable {
    @DocumentID var id: String?
    let fromUid: String
    let toUid: String
    let status: String
    @ServerTimestamp var createdAt: Date? = nil

    enum Field: String, FirestoreFieldKey {
        case fromUid
        case toUid
        case status
        case createdAt
    }
}

/// Worlds/{worldId} 문서 모델
struct World: Codable {
    @DocumentID var id: String?
    let memberUids: [String]
    let createdAt: Date
    let endsAt: Date
    let status: String
    let winnerUid: String?

    enum Field: String, FirestoreFieldKey {
        case memberUids
        case createdAt
        case endsAt
        case status
        case winnerUid
    }
}


/// Worlds/{worldId}/cells/{cellId} 문서 모델
struct WorldCell: Codable {
    @DocumentID var id: String?
    let ownerUid: String
    let lastCapturedAt: Date
    let lastCapturedRunId: String

    enum Field: String, FirestoreFieldKey {
        case ownerUid
        case lastCapturedAt
        case lastCapturedRunId
    }
}
