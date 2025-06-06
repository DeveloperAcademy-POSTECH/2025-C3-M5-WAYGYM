import SwiftUI
import FirebaseFirestore

struct ProfileRunningView: View {
    @StateObject private var userVM = UserViewModel()
    
    var body: some View {
        ZStack {
            Color("gang_bg_profile")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    if userVM.user.runRecords.isEmpty {
                        VStack(alignment: .center) {
                            Text("이런...!\n내 구역이 없잖아?!")
                            Text("\n구역확장을 해야겠어...!")
                        }
                        .padding(5)
                        .font(.text01)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        
                    } else {
                        ForEach(Array(userVM.user.runRecords.prefix(3)), id: \.id) { record in
                            let dateText = formatDate(record.startTime)
                            let distanceText = String(format: "%.2fkm", record.distance / 1000)
                            let durationMin = record.endTime != nil ? Int(record.endTime!.timeIntervalSince(record.startTime) / 60) : 0

                            ZStack {
                                Color.white
                                HStack {
                                    if let routeImage = record.routeImage {
                                        AsyncImage(url: URL(string: routeImage)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 100)
                                        } placeholder: {
                                            ProgressView()
                                                .frame(width: 100, height: 100)
                                        }
                                    } else {
                                        Image("route_1")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 100)
                                    }

                                    VStack(alignment: .leading) {
                                        Text(dateText)
                                        HStack {
                                            Text(distanceText)
                                            Text("\(durationMin)min")
                                        }
                                        .bold()
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .frame(height: 150)
                        }
                    }
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

#Preview {
    ProfileRunningView()
}
