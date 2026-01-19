//
//  FirebaseManager.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/18/26.
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import UIKit

enum FirestoreError: LocalizedError {
    case invalidPath
    case documentNotFound
    case decodingFailed
    case imageConversionFailed
    case uploadFailed
    case downloadFailed
    case authenticationRequired
    case userDocumentNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidPath: return "잘못된 경로입니다"
        case .documentNotFound: return "문서를 찾을 수 없습니다"
        case .decodingFailed: return "데이터 변환에 실패했습니다"
        case .imageConversionFailed: return "이미지 변환에 실패했습니다"
        case .uploadFailed: return "업로드에 실패했습니다"
        case .downloadFailed: return "다운로드에 실패했습니다"
        case .authenticationRequired: return "로그인이 필요합니다"
        case .userDocumentNotFound: return "사용자 문서를 찾을 수 없습니다"
        }
    }
}

protocol FirebaseManagerProtocol {
    // MARK: - Firestore 읽기
    /// 단일 문서 조회
    func fetch<T: Decodable>(path: String) async throws -> T
    
    /// 컬렉션 전체 조회
    func fetchCollection<T: Decodable>(path: String) async throws -> [T]
    
    /// 정렬된 컬렉션 조회
    func fetchCollection<T: Decodable>(path: String, orderBy field: String, descending: Bool) async throws -> [T]
    
    func fetchWhereEqual<T: Decodable>(
        path: String,
        field: String,
        isEqualTo value: String
    ) async throws -> [T]

    func fetchWhereArrayContains<T: Decodable>(
        path: String,
        field: String,
        value: String
    ) async throws -> [T]

    /// 문서 존재 여부
    func documentExists(path: String) async throws -> Bool

    /// 조건 일치 문서 존재 여부
    func existsWhereEqual(
        path: String,
        field: String,
        isEqualTo value: String,
        limit: Int
    ) async throws -> Bool

    /// 정렬 + 제한 컬렉션 조회
    func fetchCollection<T: Decodable>(
        path: String,
        orderBy field: String,
        descending: Bool,
        limit: Int
    ) async throws -> [T]

    /// 컬렉션 실시간 리스너
    func listenCollection(
        path: String,
        orderBy field: String,
        descending: Bool,
        handler: @escaping (Result<[QueryDocumentSnapshot], Error>) -> Void
    ) throws -> ListenerRegistration
    
    // MARK: - Firestore 쓰기
    /// 문서 생성 (ID 지정)
    func create(path: String, data: [String: Any]) async throws
    /// 문서 생성 (ID 자동 생성)
    func createWithAutoId(path: String, data: [String: Any]) async throws -> String

    /// 문서 생성/업데이트 (merge 옵션)
    func set(path: String, data: [String: Any], merge: Bool) async throws

    /// 문서 생성 (ID 자동 생성, Encodable)
    func createWithAutoId<T: Encodable>(path: String, data: T) async throws -> String
    
    /// 문서 업데이트
    func update(path: String, data: [String: Any]) async throws
    
    /// 문서 삭제
    func delete(path: String) async throws
}

final class FirebaseManager: FirebaseManagerProtocol {
    static let shared = FirebaseManager()
    init() {}
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Helper: 경로 파싱
    private func parseFirestorePath(_ path: String) throws -> DocumentReference {
        let components = path.split(separator: "/").map(String.init)
        guard components.count >= 2, components.count % 2 == 0 else {
            throw FirestoreError.invalidPath
        }
        
        var reference: DocumentReference?
        for i in stride(from: 0, to: components.count, by: 2) {
            let collectionName = components[i]
            let documentId = components[i + 1]
            
            if i == 0 {
                reference = db.collection(collectionName).document(documentId)
            } else {
                reference = reference?.collection(collectionName).document(documentId)
            }
        }
        
        guard let docRef = reference else {
            throw FirestoreError.invalidPath
        }
        return docRef
    }
    
    private func parseCollectionPath(_ path: String) throws -> CollectionReference {
        let components = path.split(separator: "/").map(String.init)
        guard components.count % 2 == 1 else {
            throw FirestoreError.invalidPath
        }
        
        if components.count == 1 {
            return db.collection(components[0])
        }
        
        var docRef: DocumentReference?
        for i in stride(from: 0, to: components.count - 1, by: 2) {
            let collectionName = components[i]
            let documentId = components[i + 1]
            
            if i == 0 {
                docRef = db.collection(collectionName).document(documentId)
            } else {
                docRef = docRef?.collection(collectionName).document(documentId)
            }
        }
        
        let finalCollectionName = components[components.count - 1]
        if let docRef = docRef {
            return docRef.collection(finalCollectionName)
        } else {
            return db.collection(finalCollectionName)
        }
    }
    
    // MARK: - Firestore 읽기
    func fetch<T: Decodable>(path: String) async throws -> T {
        let docRef = try parseFirestorePath(path)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists else {
            throw FirestoreError.documentNotFound
        }
        
        do {
            return try snapshot.data(as: T.self)
        } catch {
            print("❌ 디코딩 실패: \(error)")
            throw FirestoreError.decodingFailed
        }
    }
    
    func fetchCollection<T: Decodable>(path: String) async throws -> [T] {
        let collectionRef = try parseCollectionPath(path)
        let snapshot = try await collectionRef.getDocuments()
        
        return snapshot.documents.compactMap { document in
            do {
                return try document.data(as: T.self)
            } catch {
                print("❌ 문서 \(document.documentID) 디코딩 실패: \(error)")
                return nil
            }
        }
    }
    
    func fetchCollection<T: Decodable>(
        path: String,
        orderBy field: String,
        descending: Bool
    ) async throws -> [T] {
        let collectionRef = try parseCollectionPath(path)
        let query = collectionRef.order(by: field, descending: descending)
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            do {
                return try document.data(as: T.self)
            } catch {
                print("❌ 문서 \(document.documentID) 디코딩 실패: \(error)")
                return nil
            }
        }
    }
    
    func fetchWhereEqual<T: Decodable>(
        path: String,
        field: String,
        isEqualTo value: String
    ) async throws -> [T] {
        let collectionRef = try parseCollectionPath(path)
        let query: Query = collectionRef.whereField(field, isEqualTo: value)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            do {
                return try document.data(as: T.self)
            } catch {
                print("❌ 문서 \(document.documentID) 디코딩 실패: \(error)")
                return nil
            }
        }
    }

    func fetchWhereArrayContains<T: Decodable>(
        path: String,
        field: String,
        value: String
    ) async throws -> [T] {
        let collectionRef = try parseCollectionPath(path)
        let query: Query = collectionRef.whereField(field, arrayContains: value)
        let snapshot = try await query.getDocuments()

        return snapshot.documents.compactMap { document in
            do {
                return try document.data(as: T.self)
            } catch {
                print("❌ 문서 \(document.documentID) 디코딩 실패: \(error)")
                return nil
            }
        }
    }
    
    func fetchWhere<T: Decodable>(
        path: String,
        field: String,
        isGreaterThanOrEqualTo value: Any,
        orderBy: String,
        descending: Bool
    ) async throws -> [T] {
        let collectionRef = try parseCollectionPath(path)
        let query = collectionRef
            .whereField(field, isGreaterThanOrEqualTo: value)
            .order(by: orderBy, descending: descending)
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { document in
            do {
                return try document.data(as: T.self)
            } catch {
                print("❌ 문서 \(document.documentID) 디코딩 실패: \(error)")
                return nil
            }
        }
    }

    func documentExists(path: String) async throws -> Bool {
        let docRef = try parseFirestorePath(path)
        let snapshot = try await docRef.getDocument()
        return snapshot.exists
    }

    func existsWhereEqual(
        path: String,
        field: String,
        isEqualTo value: String,
        limit: Int
    ) async throws -> Bool {
        let collectionRef = try parseCollectionPath(path)
        let snapshot = try await collectionRef
            .whereField(field, isEqualTo: value)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.isEmpty == false
    }

    func fetchCollection<T: Decodable>(
        path: String,
        orderBy field: String,
        descending: Bool,
        limit: Int
    ) async throws -> [T] {
        let collectionRef = try parseCollectionPath(path)
        let snapshot = try await collectionRef
            .order(by: field, descending: descending)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            do {
                return try document.data(as: T.self)
            } catch {
                print("❌ 문서 \(document.documentID) 디코딩 실패: \(error)")
                return nil
            }
        }
    }

    func listenCollection(
        path: String,
        orderBy field: String,
        descending: Bool,
        handler: @escaping (Result<[QueryDocumentSnapshot], Error>) -> Void
    ) throws -> ListenerRegistration {
        let collectionRef = try parseCollectionPath(path)
        let query = collectionRef.order(by: field, descending: descending)
        return query.addSnapshotListener { snapshot, error in
            if let error {
                handler(.failure(error))
                return
            }
            handler(.success(snapshot?.documents ?? []))
        }
    }
    
    // MARK: - Firestore 쓰기
    func create(path: String, data: [String: Any]) async throws {
        let docRef = try parseFirestorePath(path)
        try await docRef.setData(data, merge: true)
    }
    
    func createWithAutoId(path: String, data: [String: Any]) async throws -> String {
        let collectionRef = try parseCollectionPath(path)
        let docRef = try await collectionRef.addDocument(data: data)
        return docRef.documentID
    }

    func set(path: String, data: [String: Any], merge: Bool) async throws {
        let docRef = try parseFirestorePath(path)
        try await docRef.setData(data, merge: merge)
    }

    func createWithAutoId<T: Encodable>(path: String, data: T) async throws -> String {
        let collectionRef = try parseCollectionPath(path)
        let docRef = collectionRef.document()
        try docRef.setData(from: data)
        return docRef.documentID
    }
    
    func update(path: String, data: [String: Any]) async throws {
        let docRef = try parseFirestorePath(path)
        try await docRef.updateData(data)
    }
    
    enum BatchOption {
        case update(path: String, data: [String: Any]) // 기존 문서에 업데이트, 문서가 없다면 누락
        case upsert(path: String, data: [String: Any]) // 기존 문서에 업데이트, 없다면 문서 생성
    }
    
    // MARK: - Firestore 삭제
    func delete(path: String) async throws {
        let docRef = try parseFirestorePath(path)
        try await docRef.delete()
    }
    
    func deleteWhereEqual(
        path: String,
        field: String,
        isEqualTo value: String
    ) async throws {
        let collectionRef = try parseCollectionPath(path)
        let query = collectionRef.whereField(field, isEqualTo: value)
        let snapshot = try await query.getDocuments()

        guard snapshot.documents.isEmpty == false else { return }

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        try await batch.commit()
    }
}
