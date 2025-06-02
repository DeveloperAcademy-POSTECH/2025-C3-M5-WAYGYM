import Foundation
import Combine

final class UserViewModel: ObservableObject {
    @Published var user: UserModel

    @Published var runRecords: [RunRecordModel] = []
    @Published var totalDistance: Double = 0
    @Published var totalCaptureArea: Double = 0

    private var cancellables = Set<AnyCancellable>()

    init(user: UserModel) {
        self.user = user
        self.runRecords = user.runRecords
        
        $runRecords
            .sink { [weak self] runs in
                self?.totalDistance = runs.map { $0.totalDistance }.reduce(0, +)
                self?.totalCaptureArea = runs.map { $0.capturedAreaValue }.reduce(0, +)
            }
            .store(in: &cancellables)
    }

    func addRunRecord(_ run: RunRecordModel) {
        runRecords.append(run)
    }
}
