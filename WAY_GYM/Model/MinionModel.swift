import Foundation

// minion = distance
struct MinionDefinitionModel: Identifiable, Codable, Equatable {
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
        return index == 1 ? 5 : Double((index - 1) * 10)
    }

    func loadDummyWeapons() {
        allMinions = [
            MinionDefinitionModel(
                id: "minion_1",
                name: "노터",
                description: "말은 안 해도 눈빛 하나로\n대화 끝나는 그림자 에이스",
                iconName: "minion_1",
                unlockNumber: unlockDistance(for: 1)
            ),
            MinionDefinitionModel(
                id: "minion_2",
                name: "모호크",
                description: "머리 하나로 위협 끝, 싸움은 주먹보다 헤어스타일이 먼저",
                iconName: "minion_2",
                unlockNumber: unlockDistance(for: 2)
            ),
            MinionDefinitionModel(
                id: "minion_3",
                name: "보스",
                description: "진짜 보스는 아니지만,\n태도만큼은 조직의 중심",
                iconName: "minion_3",
                unlockNumber: unlockDistance(for: 3)
            ),
            MinionDefinitionModel(
                id: "minion_4",
                name: "불곰",
                description: "말보다 주먹이 빠른 야성의 사나이",
                iconName: "minion_4",
                unlockNumber: unlockDistance(for: 4)
            ),
            MinionDefinitionModel(
                id: "minion_5",
                name: "두건",
                description: "머리부터 시비 걸고 들어오는\n길거리 전담 지휘관",
                iconName: "minion_5",
                unlockNumber: unlockDistance(for: 5)
            ),
            MinionDefinitionModel(
                id: "minion_6",
                name: "스컬",
                description: "해골 티 하나로 존재감 폭발,\n실제론 웃음 많은 형",
                iconName: "minion_6",
                unlockNumber: unlockDistance(for: 6)
            ),
            MinionDefinitionModel(
                id: "minion_7",
                name: "알로하",
                description: "한 손엔 칵테일, 한 손엔 주먹 - 열대의 살벌한 휴양러",
                iconName: "minion_7",
                unlockNumber: unlockDistance(for: 7)
            ),
            MinionDefinitionModel(
                id: "minion_8",
                name: "시가",
                description: "말보다 연기가 먼저 나오는\n중후한 협상의 장인",
                iconName: "minion_8",
                unlockNumber: unlockDistance(for: 8)
            ),
            MinionDefinitionModel(
                id: "minion_9",
                name: "강타",
                description: "1타1킬 전담 처리반,\n그가 움직이면 소리부터 사라진다",
                iconName: "minion_9",
                unlockNumber: unlockDistance(for: 9)
            ),
            MinionDefinitionModel(
                id: "minion_10",
                name: "주디제이",
                description: "남자 아니고 여캐임\n그녀의 쾌활함에 모두가 놀란다",
                iconName: "minion_10",
                unlockNumber: unlockDistance(for: 10)
                )
        ]
    }
}
