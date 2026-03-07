//
//  RootView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject
    private var coordinator: AppCoordinator
    private let moduleFactory: ModuleFactoryProtocol
    
    @StateObject var runRecordStore: RunRecordStore
    @StateObject var userStore: UserStore
    @StateObject var friendStore: FriendStore
    @StateObject var duoBattleStore: DuoBattleStore
    
    @StateObject private var locationManager: LocationManager
    private let userRepository: UserRepositoryProtocol

    init(
        moduleFactory: ModuleFactoryProtocol,
        userRepository: UserRepositoryProtocol = UserRepository(),
        runRecordStore: RunRecordStore = RunRecordStore(),
        userStore: UserStore = UserStore(),
        friendStore: FriendStore = FriendStore(),
        duoBattleStore: DuoBattleStore = DuoBattleStore(),
        injectedLocationManager: LocationManager? = nil
    ) {
        self.moduleFactory = moduleFactory
        self.userRepository = userRepository
        _runRecordStore = StateObject(wrappedValue: runRecordStore)
        _userStore = StateObject(wrappedValue: userStore)
        _friendStore = StateObject(wrappedValue: friendStore)
        _duoBattleStore = StateObject(wrappedValue: duoBattleStore)

        let resolvedLocationManager: LocationManager
        if let locationManager = injectedLocationManager {
            locationManager.userStore = userStore
            locationManager.runRecordStore = runRecordStore
            resolvedLocationManager = locationManager
        } else {
            resolvedLocationManager = LocationManager(
                userStore: userStore,
                runRecordStore: runRecordStore
            )
        }
        _locationManager = StateObject(wrappedValue: resolvedLocationManager)
    }

    @State private var authListener: AuthStateDidChangeListenerHandle?
    @State private var isBootstrapping: Bool = false
    @State private var bootProgress: Double = 0
    @State private var bootStatusText: String = "접속 준비 중..."
    @State private var lastObservedUid: String?
    @State private var hasBootstrappedForCurrentLogin: Bool = false

    var body: some View {
        ZStack {
            NavigationStack(path: $coordinator.path) {
                Group {
                    moduleFactory.make(coordinator.root, locationManager: locationManager)
                }
                .navigationDestination(for: AppRouter.self) { route in
                    moduleFactory.make(route, locationManager: locationManager)
                }
                .onAppear {
                    authListener = Auth.auth().addStateDidChangeListener { _, _ in
                        Task { await decideEntryAfterAuth() }
                    }
                }
                .onDisappear {
                    if let authListener {
                        Auth.auth().removeStateDidChangeListener(authListener)
                        self.authListener = nil
                    }
                }
            }

            if isBootstrapping {
                SplashLoadingView(progress: bootProgress, statusText: bootStatusText)
                    .transition(.opacity)
                    .zIndex(10)
                    .allowsHitTesting(true)
                    .accessibilityIdentifier("splash_loading_view")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isBootstrapping)
        .environmentObject(runRecordStore)
        .environmentObject(userStore)
        .environmentObject(friendStore)
        .environmentObject(duoBattleStore)
        .environmentObject(locationManager)
    }

    @MainActor
    private func startBoot(message: String) {
        isBootstrapping = true
        bootProgress = 0
        bootStatusText = message
    }

    @MainActor
    private func updateBoot(progress: Double, message: String) {
        bootProgress = max(0, min(1, progress))
        bootStatusText = message
    }

    @MainActor
    private func finishBoot(message: String) async {
        bootProgress = 1
        bootStatusText = message
        try? await Task.sleep(for: .milliseconds(180))
        isBootstrapping = false
    }

    @MainActor
    func decideEntryAfterAuth() async {
        let currentUid = Auth.auth().currentUser?.uid
        if currentUid != lastObservedUid {
            lastObservedUid = currentUid
            hasBootstrappedForCurrentLogin = false
        }

        guard let uid = currentUid else {
            runRecordStore.resetRunRecordStore()
            userStore.resetUserStore()
            friendStore.resetFriendStore()
            duoBattleStore.resetDuoBattleStore()
            if coordinator.root != .auth { coordinator.replaceRoot(.auth) }
            isBootstrapping = false
            return
        }

        let shouldBootstrap = !hasBootstrappedForCurrentLogin
        if shouldBootstrap {
            startBoot(message: "유저 접속 상태 확인 중...")
        }

        do {
            if shouldBootstrap {
                updateBoot(progress: 0.1, message: "프로필 존재 여부 확인 중...")
            }
            let exists = try await userRepository.doesUserExist(uid: uid)
            let target: AppRouter = exists ? .main : .profileSetup
            if coordinator.root != target { coordinator.replaceRoot(target) }

            if exists, shouldBootstrap {
                await hydrateStoresAfterLogin()
                await finishBoot(message: "접속 준비 완료")
                hasBootstrappedForCurrentLogin = true
            } else if shouldBootstrap {
                await finishBoot(message: "프로필 설정으로 이동")
                hasBootstrappedForCurrentLogin = true
            }
        } catch {
            if coordinator.root != .profileSetup { coordinator.replaceRoot(.profileSetup) }
            if shouldBootstrap {
                await finishBoot(message: "프로필 설정으로 이동")
                hasBootstrappedForCurrentLogin = true
            }
        }
    }
    
    /// 앱에서 계속 사용할 핵심 데이터를 서버에서 새로 받아와 Store에 채운다.
    @MainActor
    private func hydrateStoresAfterLogin() async {
        updateBoot(progress: 0.25, message: "러닝 기록 불러오는 중...")
        await runRecordStore.refresh()

        updateBoot(progress: 0.45, message: "사용자 정보 동기화 중...")
        await userStore.refresh()

        updateBoot(progress: 0.62, message: "친구 정보 동기화 중...")
        await friendStore.refresh()

        updateBoot(progress: 0.82, message: "경쟁전 결과 확인 중...")
        await duoBattleStore.resolvePendingResultIfNeededOnLaunch()

        updateBoot(progress: 0.94, message: "경쟁전 상태 갱신 중...")
        await duoBattleStore.refresh()
    }
}
