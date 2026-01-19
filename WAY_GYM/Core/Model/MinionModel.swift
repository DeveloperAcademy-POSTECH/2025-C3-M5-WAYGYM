import Foundation

struct MinionDefinitionModel: Identifiable, Codable, Equatable {
    let minionId: Int  /// 1, 2, 3 ... 순번 (서버의 minionId와 동일)
    let name: String
    let description: String
    let iconName: String

    var id: Int { minionId }
}

final class MinionModel: ObservableObject {
    @Published var allMinions: [MinionDefinitionModel] = []

    init() {
        loadMinionsData()
    }
    
    func loadMinionsData() {
        allMinions = [
            MinionDefinitionModel(
                minionId: 1,
                name: "노터",
                description: "말은 안 해도 눈빛 하나로\n대화 끝내는 그림자 에이스",
                iconName: "minion_1"
            ),
            MinionDefinitionModel(
                minionId: 2,
                name: "모호크",
                description: "머리 하나로 위협 끝, 싸움은 주먹보다 헤어스타일이 먼저",
                iconName: "minion_2"
            ),
            MinionDefinitionModel(
                minionId: 3,
                name: "보스",
                description: "진짜 보스는 아니지만,\n태도만큼은 조직의 중심",
                iconName: "minion_3"
            ),
            MinionDefinitionModel(
                minionId: 4,
                name: "불곰",
                description: "말보다 주먹이 빠른 야성의 사나이",
                iconName: "minion_4"
            ),
            MinionDefinitionModel(
                minionId: 5,
                name: "두건",
                description: "머리부터 시비 걸고 들어오는\n길거리 전담 지휘관",
                iconName: "minion_5"
            ),
            MinionDefinitionModel(
                minionId: 6,
                name: "스컬",
                description: "해골 티 하나로 존재감 폭발,\n실제론 웃음 많은 형",
                iconName: "minion_6"
            ),
            MinionDefinitionModel(
                minionId: 7,
                name: "알로하",
                description: "한 손엔 칵테일, 한 손엔 주먹 - 열대의 살벌한 휴양러",
                iconName: "minion_7"
            ),
            MinionDefinitionModel(
                minionId: 8,
                name: "시가",
                description: "말보다 연기가 먼저 나오는\n중후한 협상의 장인",
                iconName: "minion_8"
            ),
            MinionDefinitionModel(
                minionId: 9,
                name: "강타",
                description: "1타1킬 전담 처리반,\n그가 움직이면 소리부터 사라진다",
                iconName: "minion_9"
            ),
            MinionDefinitionModel(
                minionId: 10,
                name: "주디제이",
                description: "그녀의 쾌활함에\n모두가 고개를 조아린다",
                iconName: "minion_10"
                )
        ]
    }
}
