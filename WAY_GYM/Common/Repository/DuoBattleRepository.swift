import Foundation
import FirebaseFirestore

struct DuoBattleStatus {
    let myCellCount: Int
    let opponentCellCount: Int
    let endsAt: Date
}

struct DuoPendingWorldResult {
    let worldId: String
    let winnerUid: String?
    let opponentUid: String?
    let opponentName: String
    let myCellCount: Int
    let opponentCellCount: Int
    let cells: [WorldCell]
    let unlockedMinionId: Int?
}

protocol DuoBattleRepositoryProtocol {
    // MARK: - 홈 뱃지
    func fetchDuoBattleStatus(worldId: String, myUid: String) async throws -> DuoBattleStatus
    func fetchWorldCells(worldId: String) async throws -> [WorldCell]

    // MARK: - 승패 결과
    func resolvePendingWorldResultOnLaunch(uid: String) async throws -> DuoPendingWorldResult?
    func clearPendingWorldResult(uid: String) async throws
}

final class DuoBattleRepository: DuoBattleRepositoryProtocol {
    private let firebaseManager: FirestoreManagerProtocol

    init(firebaseManager: FirestoreManagerProtocol = FirestoreManager.shared) {
        self.firebaseManager = firebaseManager
    }

    func fetchDuoBattleStatus(worldId: String, myUid: String) async throws -> DuoBattleStatus {
        let world: World = try await firebaseManager.fetch(path: "Worlds/\(worldId)")
        let opponentUid = world.memberUids.first(where: { $0 != myUid })
        let cellsPath = "Worlds/\(worldId)/cells"

        async let myCells: [WorldCell] = firebaseManager.fetchWhereEqual(
            path: cellsPath,
            field: WorldCell.Field.ownerUid.key,
            isEqualTo: myUid
        )

        async let opponentCells: [WorldCell] = {
            guard let opponentUid else { return [] }
            return try await firebaseManager.fetchWhereEqual(
                path: cellsPath,
                field: WorldCell.Field.ownerUid.key,
                isEqualTo: opponentUid
            )
        }()

        let (mine, opponent) = try await (myCells, opponentCells)
        return DuoBattleStatus(
            myCellCount: mine.count,
            opponentCellCount: opponent.count,
            endsAt: world.endsAt
        )
    }

    func fetchWorldCells(worldId: String) async throws -> [WorldCell] {
        let path = "Worlds/\(worldId)/cells"
        return try await firebaseManager.fetchCollection(path: path)
    }

    func resolvePendingWorldResultOnLaunch(uid: String) async throws -> DuoPendingWorldResult? {
        let user: User = try await firebaseManager.fetch(path: FirestoreDocumentPath(collection: .users, documentId: uid))

        if let worldId = user.pendingWorldResult {
            return try await buildPendingResult(uid: uid, worldId: worldId)
        }

        guard let activeWorldId = user.activeDuoWorldId else {
            return nil
        }

        let world: World = try await firebaseManager.fetch(path: "Worlds/\(activeWorldId)")
        if world.endsAt > Date() {
            return nil
        }

        if world.status == "ended" {
            try await promoteEndedWorldToPendingForUser(uid: uid, worldId: activeWorldId)
            return try await buildPendingResult(uid: uid, worldId: activeWorldId)
        }

        try await endWorldIfNeeded(worldId: activeWorldId)

        let refreshedUser: User = try await firebaseManager.fetch(path: FirestoreDocumentPath(collection: .users, documentId: uid))
        let pendingWorldId: String
        if let pending = refreshedUser.pendingWorldResult {
            pendingWorldId = pending
        } else {
            try await promoteEndedWorldToPendingForUser(uid: uid, worldId: activeWorldId)
            pendingWorldId = activeWorldId
        }
        return try await buildPendingResult(uid: uid, worldId: pendingWorldId)
    }

    func clearPendingWorldResult(uid: String) async throws {
        let path = FirestoreDocumentPath(collection: .users, documentId: uid)
        try await firebaseManager.update(
            path: path,
            data: [User.Field.pendingWorldResult.key: FieldValue.delete()]
        )
    }

    private func promoteEndedWorldToPendingForUser(uid: String, worldId: String) async throws {
        let path = FirestoreDocumentPath(collection: .users, documentId: uid)
        try await firebaseManager.update(
            path: path,
            data: [
                User.Field.activeDuoWorldId.key: FieldValue.delete(),
                User.Field.pendingWorldResult.key: worldId
            ]
        )
    }

    private func buildPendingResult(uid: String, worldId: String) async throws -> DuoPendingWorldResult {
        let world: World = try await firebaseManager.fetch(path: "Worlds/\(worldId)")
        let cells: [WorldCell] = try await fetchWorldCells(worldId: worldId)
        let opponentUid = world.memberUids.first(where: { $0 != uid })

        let opponentName: String
        if let opponentUid {
            let user: User? = try? await firebaseManager.fetch(path: FirestoreDocumentPath(collection: .users, documentId: opponentUid))
            opponentName = user?.displayName ?? "알 수 없음"
        } else {
            opponentName = "알 수 없음"
        }

        var myCount = 0
        var opponentCount = 0
        for cell in cells {
            if cell.ownerUid == uid {
                myCount += 1
            } else if let opponentUid, cell.ownerUid == opponentUid {
                opponentCount += 1
            }
        }

        var unlockedMinionId: Int? = nil
        if world.winnerUid == uid {
            let unlocks: [MinionUnlock] = try await firebaseManager.fetchWhereEqual(
                path: "Users/\(uid)/minionUnlocks",
                field: "worldId",
                isEqualTo: worldId
            )
            let latest = unlocks.max { ($0.unlockedAt) < ($1.unlockedAt) }
            if let minionId = latest?.minionId, let id = Int(minionId) {
                unlockedMinionId = id
            }
        }

        return DuoPendingWorldResult(
            worldId: worldId,
            winnerUid: world.winnerUid,
            opponentUid: opponentUid,
            opponentName: opponentName,
            myCellCount: myCount,
            opponentCellCount: opponentCount,
            cells: cells,
            unlockedMinionId: unlockedMinionId
        )
    }

    /// 원래 firebase function으로 실행하려 했던, 우승자 서버에 업데이트 하는 로직
    private func endWorldIfNeeded(worldId: String) async throws {
        let worldRef = try firebaseManager.documentReference(path: "Worlds/\(worldId)")
        let worldDoc = try await worldRef.getDocument()
        guard worldDoc.exists else { return }
        guard let world = try? worldDoc.data(as: World.self) else { return }
        if world.status == "ended" { return }

        let cellsSnapshot = try await worldRef.collection("cells").getDocuments()
        var ownerCounts: [String: Int] = [:]
        for uid in world.memberUids {
            ownerCounts[uid] = 0
        }
        for doc in cellsSnapshot.documents {
            if let ownerUid = doc.data()[WorldCell.Field.ownerUid.key] as? String {
                ownerCounts[ownerUid, default: 0] += 1
            }
        }

        let uidA = world.memberUids.first
        let uidB = world.memberUids.dropFirst().first
        let countA = uidA.flatMap { ownerCounts[$0] } ?? 0
        let countB = uidB.flatMap { ownerCounts[$0] } ?? 0
        let winnerUid: String? = {
            guard let uidA, let uidB else { return nil }
            if countA == countB { return nil }
            return countA > countB ? uidA : uidB
        }()

        let now = Date()
        let winnerRef: DocumentReference?
        if let winnerUid {
            winnerRef = try firebaseManager.documentReference(
                path: "\(FirestoreCollection.users.key)/\(winnerUid)"
            )
        } else {
            winnerRef = nil
        }

        try await firebaseManager.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            var winnerSnapshot: DocumentSnapshot?
            do {
                snapshot = try transaction.getDocument(worldRef)
                if let winnerRef {
                    winnerSnapshot = try transaction.getDocument(winnerRef)
                }
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard snapshot.exists else { return nil }
            let status = snapshot.data()?[World.Field.status.key] as? String
            if status == "ended" { return nil }

            var worldUpdate: [String: Any] = [
                World.Field.status.key: "ended"
            ]
            if let winnerUid {
                worldUpdate[World.Field.winnerUid.key] = winnerUid
            } else {
                worldUpdate[World.Field.winnerUid.key] = FieldValue.delete()
            }
            transaction.updateData(worldUpdate, forDocument: worldRef)

            for uid in world.memberUids {
                let userRef: DocumentReference
                do {
                    userRef = try self.firebaseManager.documentReference(
                        path: "\(FirestoreCollection.users.key)/\(uid)"
                    )
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                transaction.updateData(
                    [
                        User.Field.activeDuoWorldId.key: FieldValue.delete(),
                        User.Field.pendingWorldResult.key: worldId
                    ],
                    forDocument: userRef
                )
            }

            if let winnerRef {
                let nextMinionNumber = winnerSnapshot?.data()?[User.Field.nextMinionNumber.key] as? Int ?? 1
                let minionId = "\(nextMinionNumber)"
                let opponentUid = world.memberUids.first(where: { $0 != winnerRef.documentID }) ?? ""
                let unlockRef = winnerRef.collection("minionUnlocks").document(minionId)

                transaction.setData(
                    [
                        "minionId": minionId,
                        "unlockedAt": now,
                        "worldId": worldId,
                        "opponentUid": opponentUid
                    ],
                    forDocument: unlockRef,
                    merge: true
                )
                transaction.updateData(
                    [User.Field.nextMinionNumber.key: nextMinionNumber + 1],
                    forDocument: winnerRef
                )
            }
            return nil
        }
    }
}
