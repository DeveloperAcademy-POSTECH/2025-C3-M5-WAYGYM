import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ProfileView: View {
    @StateObject private var userVM = UserViewModel()
    
    @StateObject private var minionModel = MinionModel()
    @State private var selectedWeapon: WeaponDefinitionModel? = nil
    
    @EnvironmentObject var router: AppRouter
    @StateObject private var runRecordVM = RunRecordViewModel()
    
    private var totalDistance: Double {
        userVM.user.runRecords.map { $0.distance }.reduce(0, +) / 1000
    }
    
    private var recentMinions: [MinionDefinitionModel] {
        minionModel.allMinions
            .filter { totalDistance >= $0.unlockNumber }
            .suffix(3)
    }
    
    private var hasRecentMinions: Bool {
        !recentMinions.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gang_bg_profile
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 유저 설명 vstack
                        VStack {
                            ZStack {
                                Image("Flash")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 180)
                                
                                Image(selectedWeapon != nil ? "main_\(selectedWeapon!.id)" : "main_basic")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 200)
                                    .padding(.bottom, -20)
                                
                                VStack {
                                    HStack {
                                        Spacer()
                                        VStack {
                                            
                                            NavigationLink(destination: WeaponListView(selectedWeapon: $selectedWeapon)
                                                .foregroundStyle(Color.gang_text_2)
                                                .environmentObject(WeaponViewModel())  // WeaponViewModel은 @EnvironmentObject로 runRecordVM 사용 중
                                                .environmentObject(runRecordVM))       // runRecordVM 환경 객체 주입
                                            
                                            {
                                                ZStack {
                                                    Image("box")
                                                        .resizable()
                                                        .frame(width: 52, height: 52)
                                                    
                                                    Image(selectedWeapon?.imageName ?? "weapon_0")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 40)
                                                }
                                            }
                                            Text("무기")
                                                .font(.title02)
                                        }
                                    }
                                    Spacer()
                                } // 무기 선택
                            } // 유저 아이콘 zstack
                            .padding()
                            
                            Group {
                                Text("한성인")
                                    .font(.title01)
                                    .padding(.bottom, 2)
                                
                                Text("남구 연일읍 1대손파 형님")
                            }
                            .foregroundStyle(Color.white)
                        } // 유저 설명 vstack
                        .padding(.bottom, 15)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("총 차지한 영역")
                                    .font(.text01)
                                    .padding(.bottom, 8)
                                
                                Text("\(runRecordVM.totalCapturedAreaValue)m²")
                                    .font(.title01)
                            }
                            .padding(20)
                            .customBorder()
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("총 이동한 거리")
                                    .font(.text01)
                                    .padding(.bottom, 8)
                                
                                Text("\(runRecordVM.totalDistance, specifier: "%.2f") m")
                                    .font(.title01)
                            }
                            .padding(20)
                            .customBorder()
                        }
                        
                        VStack {
                            HStack {
                                Text("나의 똘마니")
                                    .font(.title01)
                                Spacer()
                                NavigationLink(destination: MinionListView()) {
                                    Text("모두 보기")
                                }
                                .opacity(hasRecentMinions ? 1 : 0)
                                .disabled(!hasRecentMinions)
                            }
                            
                            RecentMinionsView()
                                .padding(.vertical, 4)
                                .font(.text01)
                                .foregroundColor(Color.gang_text_2)
                        }
                        .padding(20)
                        .customBorder()
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("구역순찰 기록")
                                    .font(.title01)
                                Spacer()
                                if hasRecentMinions {
                                    NavigationLink(destination: RunningListView()
                                                  .foregroundColor(Color.gang_text_2)) {
                                        Text("모두 보기")
                                    }
                                }
                            }
                            ProfileRunningView()
                                .padding(.vertical, 4)
                                .foregroundColor(Color.gang_text_2)
                        }
                        .padding(20)
                        .customBorder()
                    }
                    .padding(.horizontal, 25)
                }
                
                VStack {
                    Spacer()
                    
                    // 홈 버튼
                    Button(action: {
                        router.currentScreen = .main
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black, lineWidth: 3)
                                )
                            
                            Text("구역 확장하러 가기")
                                .font(.title02)
                                .foregroundStyle(Color.black)
                                .padding(.vertical, 22)
                        }
                        .padding(.horizontal, 25)
                    }
                    .padding(.bottom, 5)
                }
            }
        }
        .onAppear {
            runRecordVM.fetchAndSumDistances()
            runRecordVM.fetchAndSumCapturedValue()
        }
    }
    
    private func formatNumber(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }
}

// MARK: - UserViewModel
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
                
                let dataList = documents.compactMap { try? $0.data(as: RunRecordModels.self) }
                DispatchQueue.main.async {
                    self.user.runRecords = dataList
                }
            }
    }
}

// MARK: - Custom Border Modifier
struct CustomBorderModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .overlay(
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                    Spacer()
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 4)
                }
                .padding(.horizontal, 2)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.black, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func customBorder(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(CustomBorderModifier(cornerRadius: cornerRadius))
    }
}

#Preview {
    ProfileView()
        .environmentObject(MinionViewModel())
        .environmentObject(WeaponViewModel())
        .environmentObject(AppRouter())
        .font(.text01)
        .foregroundColor(Color.gang_text_2)
}
