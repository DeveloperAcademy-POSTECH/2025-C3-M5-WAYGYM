//
//  ResultView.swift
//  WAY_GYM
//
//  Created by Leo on 6/9/25.
//

import SwiftUI

// MARK: - 결과 뷰
struct ResultView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showResult: Bool
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            List(locationManager.runRecordList) { data in
                VStack(alignment: .leading, spacing: 6) {
                    RouteMapView(coordinates: data.coordinateList)
                        .frame(height: 200)
                        .cornerRadius(10)
                    
                    Text(String(format: "이동 거리: %.3f m", data.distance))
                    // Text(String(format: "걸음 수: %.0f 걸음", data.stepCount))
                    // Text(String(format: "소모 칼로리: %.1f kcal", data.caloriesBurned))
                    Text("시작 시간: \(data.startTime, formatter: dateFormatter)")
                    Text("종료 시간: \(data.endTime.map { dateFormatter.string(from: $0) } ?? "진행 중")")
                    Text(String(format: "진행 시간: %.1f 분", data.duration))
                    if let imageURL = data.routeImage, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } placeholder: {
                            ProgressView()
                                .frame(height: 200)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("활동 기록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        showResult = false
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 10)
    }
}
//
//#Preview {
//    ResultView()
//}
