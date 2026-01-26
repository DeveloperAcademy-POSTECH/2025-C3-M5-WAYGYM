import Foundation
import FirebaseAuth

final class UserStore: ObservableObject {
    @Published var profile: User?
    @Published var addressRank: Int?

    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol = UserRepository()) {
        self.userRepository = userRepository
    }

    @MainActor
    func refresh() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            resetUserStore()
            return
        }

        do {
            let profile = try await userRepository.fetchUserProfile(uid: uid)
            self.profile = profile

            if let homeArea = profile.homeArea, !homeArea.isEmpty {
                let count = try await userRepository.fetchUserCountByHomeArea(homeArea)
                addressRank = count
            } else {
                addressRank = nil
            }
        } catch {
            print("⚠️ UserProfile fetch 실패: \(error.localizedDescription)")
        }
    }

    @MainActor
    func resetUserStore() {
        profile = nil
        addressRank = nil
    }
}
