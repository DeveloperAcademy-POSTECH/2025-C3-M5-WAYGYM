import Foundation

extension RunRecordModel {
    static let dummyData: [RunRecordModel] = [
        RunRecordModel(
            id: UUID(),
            startTime: RunRecordModel.makeDate("2025.05.23 08:00"),
            endTime: RunRecordModel.makeDate("2025.05.23 08:17"),
            totalDistance: 1263,
            caloriesBurned: 100,
            steps: 1600,
            routeImage: "route_1",
            capturedAreas: [[
                CoordinatePair(latitude: 37.5665, longitude: 126.9780),
                CoordinatePair(latitude: 37.5666, longitude: 126.9782),
                CoordinatePair(latitude: 37.5664, longitude: 126.9784),
                CoordinatePair(latitude: 37.5663, longitude: 126.9781)
            ]],
            capturedAreaValue: 30000
        ),
        RunRecordModel(
            id: UUID(),
            startTime: RunRecordModel.makeDate("2025.05.25 07:34"),
            endTime: RunRecordModel.makeDate("2025.05.25 07:42"),
            totalDistance: 826,
            caloriesBurned: 70,
            steps: 1100,
            routeImage: "route_2",
            capturedAreas: []
        ),
        RunRecordModel(
            id: UUID(),
            startTime: RunRecordModel.makeDate("2025.05.26 08:46"),
            endTime: RunRecordModel.makeDate("2025.05.26 09:10"),
            totalDistance: 1546,
            caloriesBurned: 130,
            steps: 2000,
            routeImage: "route_3",
            capturedAreas: [[
                CoordinatePair(latitude: 37.5655, longitude: 126.9770),
                CoordinatePair(latitude: 37.5657, longitude: 126.9773),
                CoordinatePair(latitude: 37.5656, longitude: 126.9777),
                CoordinatePair(latitude: 37.5654, longitude: 126.9776),
                CoordinatePair(latitude: 37.5653, longitude: 126.9774)
            ]],
            capturedAreaValue: 37260
        ),
        RunRecordModel(
            id: UUID(),
            startTime: RunRecordModel.makeDate("2025.05.28 06:23"),
            endTime: RunRecordModel.makeDate("2025.05.28 06:28"),
            totalDistance: 2275,
            caloriesBurned: 180,
            steps: 3000,
            routeImage: "route_4",
            capturedAreas: [
                [
                    CoordinatePair(latitude: 37.5645, longitude: 126.9760),
                    CoordinatePair(latitude: 37.5646, longitude: 126.9762),
                    CoordinatePair(latitude: 37.5644, longitude: 126.9763),
                    CoordinatePair(latitude: 37.5643, longitude: 126.9761)
                ],
                [
                    CoordinatePair(latitude: 37.5649, longitude: 126.9765),
                    CoordinatePair(latitude: 37.5650, longitude: 126.9767),
                    CoordinatePair(latitude: 37.5648, longitude: 126.9768),
                    CoordinatePair(latitude: 37.5647, longitude: 126.9766)
                ]
            ],
            capturedAreaValue: 82619
        ),
        RunRecordModel(
            id: UUID(),
            startTime: RunRecordModel.makeDate("2025.05.28 07:40"),
            endTime: RunRecordModel.makeDate("2025.05.28 07:54"),
            totalDistance: 1275,
            caloriesBurned: 90,
            steps: 1400,
            routeImage: "route_5",
            capturedAreas: []
        ),
        RunRecordModel(
            id: UUID(),
            startTime: RunRecordModel.makeDate("2025.06.01 06:46"),
            endTime: RunRecordModel.makeDate("2025.06.01 07:24"),
            totalDistance: 2347,
            caloriesBurned: 170,
            steps: 2900,
            routeImage: "route_6",
            capturedAreas: [
                [
                    CoordinatePair(latitude: 36.0310, longitude: 129.3620),
                    CoordinatePair(latitude: 36.0312, longitude: 129.3623),
                    CoordinatePair(latitude: 36.0309, longitude: 129.3625),
                    CoordinatePair(latitude: 36.0307, longitude: 129.3622),
                    CoordinatePair(latitude: 36.0302, longitude: 129.3622),
                ],
                [
                    CoordinatePair(latitude: 36.0320, longitude: 129.3630),
                    CoordinatePair(latitude: 36.0322, longitude: 129.3632),
                    CoordinatePair(latitude: 36.0319, longitude: 129.3634)
                ],
                [
                    CoordinatePair(latitude: 36.0300, longitude: 129.3610),
                    CoordinatePair(latitude: 36.0302, longitude: 129.3612),
                    CoordinatePair(latitude: 36.0299, longitude: 129.3614),
                    CoordinatePair(latitude: 36.0297, longitude: 129.3611),
                    CoordinatePair(latitude: 36.0293, longitude: 129.3618),
                    CoordinatePair(latitude: 36.0294, longitude: 129.3622)

                ],
                [
                    CoordinatePair(latitude: 36.0305, longitude: 129.3600),
                    CoordinatePair(latitude: 36.0307, longitude: 129.3603),
                    CoordinatePair(latitude: 36.0304, longitude: 129.3605),
                    CoordinatePair(latitude: 36.0302, longitude: 129.3602)
                ],
                [
                    CoordinatePair(latitude: 37.5649, longitude: 126.9765),
                    CoordinatePair(latitude: 37.5650, longitude: 126.9767),
                    CoordinatePair(latitude: 37.5648, longitude: 126.9768),
                    CoordinatePair(latitude: 37.5647, longitude: 126.9766)
                ]
            ],
            capturedAreaValue: 1292379
        ),
        RunRecordModel(
            id: UUID(),
            startTime: RunRecordModel.makeDate("2025.06.01 18:03"),
            endTime: RunRecordModel.makeDate("2025.06.01 18:54"),
            totalDistance: 9329,
            caloriesBurned: 320,
            steps: 8200,
            routeImage: "route_5.png",
            capturedAreas: []
        ),
    ]
}
