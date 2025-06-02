import Foundation

// weapon = area
struct WeaponDefinitionModel: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let imageName: String
    
    let unlockNumber: Double
}

final class WeaponModel: ObservableObject {
    @Published var allWeapons: [WeaponDefinitionModel] = []
    @Published var ownedWeaponIDs: Set<String> = []

    init() {
        loadDummyWeapons()
    }
    
    func unlockArea(for index: Int) -> Double {
        return Double(index * 1)
    }

    func loadDummyWeapons() {
        allWeapons = [
            WeaponDefinitionModel(
                id: "1",
                name: "불꽃의 검",
                description: "1km² 달성 시 해금되는 강력한 검입니다.",
                imageName: "weapon_1",
                unlockNumber: unlockArea(for: 1)
            ),
            WeaponDefinitionModel(
                id: "2",
                name: "바람의 활",
                description: "2km² 달성 시 얻을 수 있는 빠른 활입니다.",
                imageName: "weapon_2",
                unlockNumber: unlockArea(for: 2)
            ),
            WeaponDefinitionModel(
                id: "3",
                name: "대지의 도끼",
                description: "3km² 달성 시 해금되는 묵직한 도끼입니다.",
                imageName: "weapon_3",
                unlockNumber: unlockArea(for: 3)
            ),
            WeaponDefinitionModel(
                id: "4",
                name: "번개의 창",
                description: "4km² 달성 시 얻는 전격의 창입니다.",
                imageName: "weapon_4",
                unlockNumber: unlockArea(for: 4)
            ),
            WeaponDefinitionModel(
                id: "5",
                name: "얼음의 단검",
                description: "5km² 달성 시 해금되는 날카로운 단검입니다.",
                imageName: "weapon_5",
                unlockNumber: unlockArea(for: 5)
            ),
            WeaponDefinitionModel(
                id: "6",
                name: "용의 검",
                description: "6km² 달성 시 얻을 수 있는 전설의 검입니다.",
                imageName: "weapon_6",
                unlockNumber: unlockArea(for: 6)
            ),
            WeaponDefinitionModel(
                id: "7",
                name: "암흑의 철퇴",
                description: "7km² 달성 시 해금되는 강력한 철퇴입니다.",
                imageName: "weapon_7",
                unlockNumber: unlockArea(for: 7)
            ),
            WeaponDefinitionModel(
                id: "8",
                name: "빛의 활",
                description: "8km² 달성 시 얻는 신성한 활입니다.",
                imageName: "weapon_8",
                unlockNumber: unlockArea(for: 8)
            ),
            WeaponDefinitionModel(
                id: "9",
                name: "바다의 창",
                description: "9km² 달성 시 해금되는 바다의 창입니다.",
                imageName: "weapon_9",
                unlockNumber: unlockArea(for: 9)
            ),
            WeaponDefinitionModel(
                id: "10",
                name: "천공의 검",
                description: "10km² 달성 시 얻을 수 있는 하늘의 검입니다.",
                imageName: "weapon_10",
                unlockNumber: unlockArea(for: 10)
            )
        ]
    }
}
