import Foundation

// minion = distance
struct MinionDefinitionModel: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let unlockNumber: Double
}

final class MinionModel: ObservableObject {
    @Published var allMinions: [MinionDefinitionModel] = []

    init() {
        loadDummyWeapons()
    }
    
    func unlockDistance(for index: Int) -> Double {
        return Double(index * 5)
    }

    func loadDummyWeapons() {
        allMinions = [
            MinionDefinitionModel(
                id: "minion_1",
                name: "똘똘이",
                description: "5km 달성 시",
                iconName: "minion_1",
                unlockNumber: unlockDistance(for: 1)
            ),
            MinionDefinitionModel(
                id: "minion_2",
                name: "비실이",
                description: "10km 달성 시",
                iconName: "minion_2",
                unlockNumber: unlockDistance(for: 2)
            ),
            MinionDefinitionModel(
                id: "minion_3",
                name: "퉁퉁이",
                description: "15km 달성 시",
                iconName: "minion_3",
                unlockNumber: unlockDistance(for: 3)
            ),
            MinionDefinitionModel(
                id: "minion_4",
                name: "멍청이",
                description: "20km 달성 시",
                iconName: "minion_4",
                unlockNumber: unlockDistance(for: 4)
            ),
            MinionDefinitionModel(
                id: "minion_5",
                name: "깨방정이",
                description: "25km 달성 시",
                iconName: "minion_5",
                unlockNumber: unlockDistance(for: 5)
            ),
            MinionDefinitionModel(
                id: "minion_6",
                name: "딴청이",
                description: "30km 달성 시",
                iconName: "minion_6",
                unlockNumber: unlockDistance(for: 6)
            ),
            MinionDefinitionModel(
                id: "minion_7",
                name: "잠순이",
                description: "35km 달성 시",
                iconName: "minion_7",
                unlockNumber: unlockDistance(for: 7)
            ),
            MinionDefinitionModel(
                id: "minion_8",
                name: "빠순이",
                description: "40km 달성 시",
                iconName: "minion_8",
                unlockNumber: unlockDistance(for: 8)
            ),
            MinionDefinitionModel(
                id: "minion_9",
                name: "깐돌이",
                description: "45km 달성 시",
                iconName: "minion_9",
                unlockNumber: unlockDistance(for: 9)
            ),
            MinionDefinitionModel(
                id: "minion_10",
                name: "멍청이",
                description: "50km 달성 시",
                iconName: "minion_10",
                unlockNumber: unlockDistance(for: 10)
            )
        ]
    }
}
