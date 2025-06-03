import SwiftUI

struct MonthlySectionView: View {
    let month: String
    let records: [RunRecordModel]
    let allRecords: [RunRecordModel]
    let minionViewModel: MinionViewModel
    let weaponViewModel: WeaponViewModel

    var body: some View {
        let areaSum = records.reduce(0) { $0 + $1.capturedAreaValue }
        let distanceSum = records.reduce(0) { $0 + $1.totalDistance }

        VStack(alignment: .leading, spacing: 8) {
            Text(month)
                .font(.title2)
                .bold()

            HStack {
                Text("구역순찰 \(records.count)회")
                Text("\(String(format: "%.0f", areaSum))m²")
                Text("\(String(format: "%.2f", distanceSum / 1000))km")
            }

            ForEach(records.sorted(by: { $0.startTime > $1.startTime }), id: \.id) { record in
                
                let weapons = WeaponModel().allWeapons
                let minions = MinionModel().allMinions

                let weaponOnThisDate = weapons.first { weapon in
                    weaponViewModel.acquisitionDate(for: weapon, in: allRecords) == record.startTime
                }

                let minionOnThisDate = minions.first { minion in
                    minionViewModel.acquisitionDate(for: minion, in: allRecords) == record.startTime
                }

                let routeImageName = (record.routeImage ?? "route_1").replacingOccurrences(of: ".png", with: "")
                let dateText = formatDate(record.startTime)
                let distanceText = String(format: "%.2fkm", record.totalDistance / 1000)

                let content = HStack {
                    Image(routeImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100)

                    VStack(alignment: .leading) {
                        Text(dateText)

                        HStack {
                            Text(distanceText)
                            Text("\(Int(record.duration / 60))min")
                        }
                        .bold()
                    }

                    if let weapon = weaponOnThisDate {
                        Image(weapon.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30)
                    }

                    if let minion = minionOnThisDate {
                        Image(minion.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30)
                    }
                }

                ZStack {
                    Color.white

                    content
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(height: 150)
            }
        }
    }
}

struct RunningListView: View {
    @State private var runRecords = RunRecordModel.dummyData
    @StateObject private var minionViewModel = MinionViewModel()
    @StateObject private var weaponViewModel = WeaponViewModel()

    var groupedRunRecords: [String: [RunRecordModel]] {
        Dictionary(grouping: runRecords) { record in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy년 M월"
            return formatter.string(from: record.startTime)
        }
    }

    func montlyTotalArea(of records: [RunRecordModel]) -> Double {
        records.map { $0.capturedAreaValue }.reduce(0, +)
    }

    func montlyTotalDistance(of records: [RunRecordModel]) -> Double {
        records.map { $0.totalDistance }.reduce(0, +)
    }
    
    var body: some View {
        ZStack {
            Color.gray
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedRunRecords.keys.sorted(by: >), id: \.self) { month in
                        if let records = groupedRunRecords[month] {
                            MonthlySectionView(
                                month: month,
                                records: records,
                                allRecords: runRecords,
                                minionViewModel: minionViewModel,
                                weaponViewModel: weaponViewModel
                            )
                        }
                    }
                }
                .padding(.horizontal, 30)
            }
        }
    }
}

#Preview {
    RunningListView()
}
