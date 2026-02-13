import Foundation
import FirebaseFirestoreSwift

struct User: Codable {
    @DocumentID var id: String?
    let displayName: String?
    let homeArea: String?
    let sex: String?
    let friendCode: String?
    // Duo 관련
    let activeDuoWorldId: String?
    let pendingWorldResult: String?
    // 보상 관련
    let nextMinionNumber: Int?
    @ServerTimestamp var createdAt: Date? = nil

    enum Field: String, FirestoreFieldKey {
        case displayName
        case homeArea
        case sex
        case friendCode
        case activeDuoWorldId
        case pendingWorldResult
        case nextMinionNumber
        case createdAt
    }
}

// Subcollection: Users/{uid}/minionUnlocks/{minionId}
struct MinionUnlock: Codable {
    @DocumentID var id: String?   // == minionId

    let minionId: String
    let unlockedAt: Date
    let worldId: String
    let opponentUid: String
}
