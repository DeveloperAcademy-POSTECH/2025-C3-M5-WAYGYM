//
//  FirestorePath.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/21/26.
//

import Foundation
import FirebaseFirestore

// MARK: - 실제 이름
enum FirestoreCollection: String, FirestoreCollectionKey {
    case users = "Users"
    case runRecords = "RunRecords"
    case friendRequests = "friendRequests"
    case friendships = "friendships"
}


// MARK: - Keys (Field / Collection)
protocol FirestoreFieldKey {
    var key: String { get }
}

extension FirestoreFieldKey where Self: RawRepresentable, RawValue == String {
    var key: String { rawValue }
}

protocol FirestoreCollectionKey {
    var key: String { get }
}

extension FirestoreCollectionKey where Self: RawRepresentable, RawValue == String {
    var key: String { rawValue }
}

// MARK: - Paths
struct FirestoreCollectionPath: RawRepresentable {
    let rawValue: String

    init(_ collection: FirestoreCollection) {
        self.rawValue = collection.rawValue
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct FirestoreDocumentPath: RawRepresentable {
    let rawValue: String

    init(collection: FirestoreCollection, documentId: String) {
        self.rawValue = "\(collection.rawValue)/\(documentId)"
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - Firestore Convenience APIs
extension Firestore {
    func collection<C: FirestoreCollectionKey>(_ key: C) -> CollectionReference {
        collection(key.key)
    }
}

extension DocumentReference {
    func collection<C: FirestoreCollectionKey>(_ key: C) -> CollectionReference {
        collection(key.key)
    }
}

extension Query {
    func whereField<F: FirestoreFieldKey>(_ field: F, isEqualTo value: Any) -> Query {
        whereField(field.key, isEqualTo: value)
    }

    func whereField<F: FirestoreFieldKey>(_ field: F, arrayContains value: Any) -> Query {
        whereField(field.key, arrayContains: value)
    }

    func order<F: FirestoreFieldKey>(by field: F, descending: Bool = false) -> Query {
        order(by: field.key, descending: descending)
    }
}

extension Dictionary where Key == String {
    func value<F: FirestoreFieldKey>(_ field: F) -> Value? {
        self[field.key]
    }
}

// MARK: - Helpers
func firestoreData(_ pairs: (FirestoreFieldKey, Any)...) -> [String: Any] {
    Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.key, $0.1) })
}
