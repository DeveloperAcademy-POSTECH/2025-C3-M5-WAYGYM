import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

class UserViewModel: ObservableObject {
    @Published var user: UserModel
    private let db = Firestore.firestore()
    
    init() {
        self.user = UserModel(id: UUID(), runRecords: [])
        fetchRunRecordsFromFirestore()
    }
    
    func fetchRunRecordsFromFirestore() {
        db.collection("RunRecordModels")
            .order(by: "start_time", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Firestore에서 데이터 가져오기 실패: \(error?.localizedDescription ?? "No documents")")
                    return
                }

                let dataList = documents.compactMap { doc -> RunRecordModels? in
                    let data = doc.data()

                    let distance = data["distance"] as? Double ?? 0
                    let start = (data["start_time"] as? Timestamp)?.dateValue() ?? Date()
                    let end = (data["end_time"] as? Timestamp)?.dateValue()
                    let area = data["capturedAreaValue"] as? Int ?? 0
                    let routeImage = data["route_image"] as? String

                    return RunRecordModels(
                        id: doc.documentID,
                        distance: distance,
                        stepCount: 0,
                        caloriesBurned: 0,
                        startTime: start,
                        endTime: end,
                        routeImage: routeImage,
                        coordinates: [],
                        capturedAreas: [],
                        capturedAreaValue: area
                    )
                }
                DispatchQueue.main.async {
                    self.user.runRecords = dataList
                }
            }
    }
}
