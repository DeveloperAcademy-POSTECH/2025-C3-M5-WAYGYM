import SwiftUI

struct DuoWorldResultModalView: View {
    let result: DuoWorldResultState
    let onConfirm: () -> Void

    @State private var pageIndex: Int = 0
    
    var body: some View {
        ZStack {
            Color.gang_black_opacity
                .ignoresSafeArea()

            VStack(spacing: 18) {
                if pageIndex == 0 {
                    firstPage
                } else {
                    secondPage
                }
            }
            .padding(35)
            .frame(maxWidth: 340)
            .background(Color("ModalBackground"))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.yellow.opacity(0.78), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private var totalCells: Int {
        result.myCellCount + result.opponentCellCount
    }

    private var myRatioText: String {
        guard totalCells > 0 else { return "0:0" }
        let myRatio = Int((Double(result.myCellCount) / Double(totalCells) * 100).rounded())
        return "\(myRatio):\(max(0, 100 - myRatio))"
    }

    private var resultTitle: String {
        if result.didWin { return "접수 성공!" }
        if result.didLose { return "아쉽게 패배..." }
        return "무승부"
    }

    private var resultDescription: String {
        if result.didWin { return "\(myRatioText)으로 승리했습니다" }
        if result.didLose { return "\(myRatioText)으로 패배했습니다" }
        return "\(myRatioText)로 동점입니다"
    }

    private var canShowMinionStep: Bool {
        result.didWin && result.unlockedMinion != nil
    }

    private var landGapText: String {
        let diff = (result.myCellCount - result.opponentCellCount) * 100
        if diff > 0 {
            return "내가 더 딴 땅: \(diff)m²"
        }
        if diff < 0 {
            return "상대가 더 딴 땅: \(abs(diff))m²"
        }
        return "딴 땅 차이: 0m²"
    }

    private var firstPage: some View {
        VStack(spacing: 14) {
            Text(resultTitle)
                .font(.largeTitle02)
                .foregroundStyle(.white)

            Text(resultDescription)
                .font(.title03)
                .foregroundStyle(Color.yellow)

            VStack(spacing: 4) {
                Text("상대: \(result.opponentName)")
                    .font(.text01)
                    .foregroundStyle(Color.gangText2)
                Text(landGapText)
                    .font(.text01)
                    .foregroundStyle(Color.gangText2)
            }

            DuoResultMapPreview(cells: result.cells)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            Button {
                if canShowMinionStep {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pageIndex = 1
                    }
                } else {
                    onConfirm()
                }
            } label: {
                Text(canShowMinionStep ? "다음" : "확인")
                    .font(.title03)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var secondPage: some View {
        VStack(spacing: 14) {
            Text("새 똘마니 획득!")
                .font(.largeTitle03)
                .foregroundStyle(.white)

            if let minion = result.unlockedMinion {
                ZStack {
                    Image("Flash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 170)

                    Image(minion.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 135)
                        .padding(.bottom, -24)
                }
                .padding(.vertical, 2)

                Text(minion.name)
                    .font(.title01)
                    .foregroundStyle(Color.yellow)

                Text(minion.description)
                    .font(.text02)
                    .foregroundStyle(Color.gangText2)
                    .multilineTextAlignment(.center)
            }

            Button {
                onConfirm()
            } label: {
                Text("확인")
                    .font(.title03)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

private struct DuoResultMapPreview: View {
    let cells: [DuoResultCellPolygon]

    var body: some View {
        GeometryReader { geo in
            let allPoints = cells.flatMap { $0.points }
            let bounds = Bounds.from(points: allPoints)
            let projector = Projector(bounds: bounds, canvasSize: geo.size, paddingRatio: 0.1)

            ZStack {
                MiniMapBackground()

                Canvas { context, _ in
                    for cell in cells where cell.points.count >= 4 {
                        var path = Path()
                        path.move(to: projector.toPoint(cell.points[0]))
                        for point in cell.points.dropFirst() {
                            path.addLine(to: projector.toPoint(point))
                        }
                        path.closeSubpath()

                        let color = cell.isMine ? Color.green : Color.red
                        context.fill(path, with: .color(color.opacity(0.28)))
                        context.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 1)
                    }
                }
            }
        }
    }
}

#Preview("Duo Result - Win (2 Step)") {
    let cells: [DuoResultCellPolygon] = [
        DuoResultCellPolygon(
            id: "36.1000,129.3000",
            points: [
                CLPoint(latitude: 36.1000, longitude: 129.3000),
                CLPoint(latitude: 36.1000, longitude: 129.3005),
                CLPoint(latitude: 36.1005, longitude: 129.3005),
                CLPoint(latitude: 36.1005, longitude: 129.3000),
                CLPoint(latitude: 36.1000, longitude: 129.3000),
            ],
            isMine: true
        ),
        DuoResultCellPolygon(
            id: "36.1005,129.3000",
            points: [
                CLPoint(latitude: 36.1005, longitude: 129.3000),
                CLPoint(latitude: 36.1005, longitude: 129.3005),
                CLPoint(latitude: 36.1010, longitude: 129.3005),
                CLPoint(latitude: 36.1010, longitude: 129.3000),
                CLPoint(latitude: 36.1005, longitude: 129.3000),
            ],
            isMine: true
        ),
        DuoResultCellPolygon(
            id: "36.1000,129.3005",
            points: [
                CLPoint(latitude: 36.1000, longitude: 129.3005),
                CLPoint(latitude: 36.1000, longitude: 129.3010),
                CLPoint(latitude: 36.1005, longitude: 129.3010),
                CLPoint(latitude: 36.1005, longitude: 129.3005),
                CLPoint(latitude: 36.1000, longitude: 129.3005),
            ],
            isMine: false
        )
    ]

    let result = DuoWorldResultState(
        worldId: "preview-world-1",
        opponentName: "상대 길동",
        winnerUid: "my-uid",
        myUid: "my-uid",
        myCellCount: 64,
        opponentCellCount: 36,
        cells: cells,
        unlockedMinion: MinionModel().allMinions.first
    )

    return DuoWorldResultModalView(result: result, onConfirm: {})
}

#Preview("Duo Result - Lose (1 Step)") {
    let cells: [DuoResultCellPolygon] = [
        DuoResultCellPolygon(
            id: "36.2000,129.4000",
            points: [
                CLPoint(latitude: 36.2000, longitude: 129.4000),
                CLPoint(latitude: 36.2000, longitude: 129.4005),
                CLPoint(latitude: 36.2005, longitude: 129.4005),
                CLPoint(latitude: 36.2005, longitude: 129.4000),
                CLPoint(latitude: 36.2000, longitude: 129.4000),
            ],
            isMine: true
        ),
        DuoResultCellPolygon(
            id: "36.2005,129.4000",
            points: [
                CLPoint(latitude: 36.2005, longitude: 129.4000),
                CLPoint(latitude: 36.2005, longitude: 129.4005),
                CLPoint(latitude: 36.2010, longitude: 129.4005),
                CLPoint(latitude: 36.2010, longitude: 129.4000),
                CLPoint(latitude: 36.2005, longitude: 129.4000),
            ],
            isMine: false
        )
    ]

    let result = DuoWorldResultState(
        worldId: "preview-world-2",
        opponentName: "상대 철수",
        winnerUid: "opponent-uid",
        myUid: "my-uid",
        myCellCount: 36,
        opponentCellCount: 64,
        cells: cells,
        unlockedMinion: nil
    )

    return DuoWorldResultModalView(result: result, onConfirm: {})
}
