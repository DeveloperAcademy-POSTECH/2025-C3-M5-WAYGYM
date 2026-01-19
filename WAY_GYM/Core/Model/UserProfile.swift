import Foundation
import FirebaseFirestoreSwift

struct UserProfile: Codable {
    @DocumentID var id: String?
    let displayName: String?
    let homeArea: String?
    let sex: String?
    let friendCode: String?
    @ServerTimestamp var createdAt: Date?
}
