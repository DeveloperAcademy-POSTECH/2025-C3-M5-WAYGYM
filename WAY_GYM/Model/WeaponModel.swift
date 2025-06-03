import Foundation

// weapon = area
struct WeaponDefinitionModel: Identifiable, Codable, Equatable {
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
        return index == 0 ? 0 : pow(2.0, Double(index)) * 2 * 10000
    }

    func loadDummyWeapons() {
        allWeapons = [
            WeaponDefinitionModel(
                id: "0",
                name: "주먹",
                description: "무기..? 없어도\n뭐 문제있나?",
                imageName: "weapon_0",
                unlockNumber: 0
            ),
            WeaponDefinitionModel(
                id: "1",
                name: "변기파괴자",
                description: "막힌 건 뭐든지 뚫는\n근접전의 해결사",
                imageName: "weapon_1",
                unlockNumber: unlockArea(for: 1)
            ),
            WeaponDefinitionModel(
                id: "2",
                name: "폭풍의 중재자 (우산)",
                description: "비 오는 날,\n우아하게 후려치는 신사의 무기",
                imageName: "weapon_2",
                unlockNumber: unlockArea(for: 2)
            ),
            WeaponDefinitionModel(
                id: "3",
                name: "벽돌의 정석",
                description: "말 안 통하면 던져서\n이해시키는 소통 정석템",
                imageName: "weapon_3",
                unlockNumber: unlockArea(for: 3)
            ),
            WeaponDefinitionModel(
                id: "4",
                name: "의견 조율기 Mk.1",
                description: "회의가 길어질 땐,\n방망이로 빠르게 결론낸다",
                imageName: "weapon_4",
                unlockNumber: unlockArea(for: 4)
            ),
            WeaponDefinitionModel(
                id: "5",
                name: "화끈한 중재자",
                description: "열 받은 상대도 한 방에\n식혀주는 냉정한 무기",
                imageName: "weapon_5",
                unlockNumber: unlockArea(for: 5)
            ),
            WeaponDefinitionModel(
                id: "6",
                name: "천사의 숨결",
                description: "눈물과 콧물로 상대 의욕을\n말리는 비열한 필살기",
                imageName: "weapon_6",
                unlockNumber: unlockArea(for: 6)
            )
        ]
    }
}
