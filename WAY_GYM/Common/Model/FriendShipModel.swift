//
//  FriendShipModel.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/19/26.
//

import Foundation
import FirebaseFirestoreSwift

struct Friendship: Codable {
    @DocumentID var id: String?
    let memberUids: [String]

    enum Field: String, FirestoreFieldKey {
        case memberUids
    }
    
    func otherUid(for uid: String) -> String? {
        guard memberUids.count == 2 else { return nil }
        if memberUids[0] == uid { return memberUids[1] }
        if memberUids[1] == uid { return memberUids[0] }
        return nil
    }
}

struct FriendRequest: Codable {
    @DocumentID var id: String?
    let fromUid: String
    let toUid: String
    let status: String?

    enum Field: String, FirestoreFieldKey {
        case fromUid
        case toUid
        case status
    }
}

struct PendingFriendRequestWithProfile {
    let requestId: String
    let fromUid: String
    let profile: User
}
