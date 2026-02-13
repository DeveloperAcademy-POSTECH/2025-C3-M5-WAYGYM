import Foundation
import FirebaseAuth

struct DuoResultCellPolygon: Identifiable {
    let id: String
    let points: [CLPoint]
    let isMine: Bool
}

struct DuoWorldResultState {
    let worldId: String
    let opponentName: String
    let winnerUid: String?
    let myUid: String
    let myCellCount: Int
    let opponentCellCount: Int
    let cells: [DuoResultCellPolygon]
    let unlockedMinion: MinionDefinitionModel?

    var didWin: Bool { winnerUid == myUid }
    var didLose: Bool { winnerUid != nil && winnerUid != myUid }
}



final class DuoBattleStore: ObservableObject {
    @Published private(set) var activeDuoWorldId: String?
    @Published private(set) var myOwnedCellCount: Int = 0
    @Published private(set) var opponentOwnedCellCount: Int = 0
    @Published private(set) var duoEndsAt: Date?
    @Published var pendingWorldResult: DuoWorldResultState?
    @Published private(set) var lastRefreshError: String?

    private let userRepository: UserRepositoryProtocol
    private let duoBattleRepository: DuoBattleRepositoryProtocol

    init(
        userRepository: UserRepositoryProtocol = UserRepository(),
        duoBattleRepository: DuoBattleRepositoryProtocol = DuoBattleRepository()
    ) {
        self.userRepository = userRepository
        self.duoBattleRepository = duoBattleRepository
    }

    @MainActor
    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            resetDuoBattleStore()
            return
        }

        lastRefreshError = nil

        do {
            let profile = try await userRepository.fetchUserProfile(uid: uid)
            let worldId = profile.activeDuoWorldId
            activeDuoWorldId = worldId

            guard let worldId else {
                myOwnedCellCount = 0
                opponentOwnedCellCount = 0
                duoEndsAt = nil
                return
            }

            let status = try await duoBattleRepository.fetchDuoBattleStatus(worldId: worldId, myUid: uid)
            myOwnedCellCount = status.myCellCount
            opponentOwnedCellCount = status.opponentCellCount
            duoEndsAt = status.endsAt
        } catch {
            lastRefreshError = error.localizedDescription
            print("⚠️ DuoBattleStore refresh 실패: \(error.localizedDescription)")
        }
    }

    @MainActor
    func resetDuoBattleStore() {
        activeDuoWorldId = nil
        myOwnedCellCount = 0
        opponentOwnedCellCount = 0
        duoEndsAt = nil
        pendingWorldResult = nil
        lastRefreshError = nil
    }

    @MainActor
    func resolvePendingResultIfNeededOnLaunch() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            pendingWorldResult = nil
            return
        }

        do {
            if let resolved = try await duoBattleRepository.resolvePendingWorldResultOnLaunch(uid: uid) {
                pendingWorldResult = buildWorldResultState(resolved: resolved, myUid: uid)
            } else {
                pendingWorldResult = nil
            }
        } catch {
            print("⚠️ resolvePendingResultIfNeededOnLaunch 실패: \(error.localizedDescription)")
        }
    }

    @MainActor
    func clearPendingWorldResult() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await duoBattleRepository.clearPendingWorldResult(uid: uid)
            pendingWorldResult = nil
            await refresh()
        } catch {
            print("⚠️ clearPendingWorldResult 실패: \(error.localizedDescription)")
        }
    }

    private func buildWorldResultState(resolved: DuoPendingWorldResult, myUid: String) -> DuoWorldResultState {
        let minionModel = MinionModel()
        let unlockedMinion = resolved.unlockedMinionId.flatMap { id in
            minionModel.allMinions.first(where: { $0.minionId == id })
        }

        let gridSize = 0.0005
        let polygons: [DuoResultCellPolygon] = resolved.cells.compactMap { cell in
            guard let cellId = cell.id else { return nil }
            let parts = cellId.split(separator: ",", omittingEmptySubsequences: true)
            guard parts.count == 2,
                  let lat = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                  let lng = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }

            let points: [CLPoint] = [
                CLPoint(latitude: lat, longitude: lng),
                CLPoint(latitude: lat, longitude: lng + gridSize),
                CLPoint(latitude: lat + gridSize, longitude: lng + gridSize),
                CLPoint(latitude: lat + gridSize, longitude: lng),
                CLPoint(latitude: lat, longitude: lng)
            ]
            return DuoResultCellPolygon(
                id: cellId,
                points: points,
                isMine: cell.ownerUid == myUid
            )
        }

        return DuoWorldResultState(
            worldId: resolved.worldId,
            opponentName: resolved.opponentName,
            winnerUid: resolved.winnerUid,
            myUid: myUid,
            myCellCount: resolved.myCellCount,
            opponentCellCount: resolved.opponentCellCount,
            cells: polygons,
            unlockedMinion: unlockedMinion
        )
    }
}
