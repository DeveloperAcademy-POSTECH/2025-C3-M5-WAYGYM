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
    @StateObject var runRecordStore = RunRecordStore()
    @StateObject var userStore = UserStore()
    @StateObject var friendStore = FriendStore()
    private let userRepository: UserRepositoryProtocol = UserRepository()

    init(
        moduleFactory: ModuleFactoryProtocol
    ) {
        self.moduleFactory = moduleFactory
    }

    @State private var authListener: AuthStateDidChangeListenerHandle?

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Group {
                moduleFactory.make(coordinator.root)
            }
            .navigationDestination(for: AppRouter.self) { route in
                moduleFactory.make(route)
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
        .environmentObject(runRecordStore)
        .environmentObject(userStore)
        .environmentObject(friendStore)
    }
    
    @MainActor
    func decideEntryAfterAuth() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            runRecordStore.resetRunRecordStore()
            userStore.resetUserStore()
            friendStore.resetFriendStore()
            if coordinator.root != .auth { coordinator.replaceRoot(.auth) }
            return
        }

        do {
            let exists = try await userRepository.doesUserExist(uid: uid)
            let target: AppRouter = exists ? .main : .profileSetup
            if coordinator.root != target { coordinator.replaceRoot(target) }

            if exists {
                await hydrateStoresAfterLogin()
            }
        } catch {
            if coordinator.root != .profileSetup { coordinator.replaceRoot(.profileSetup) }
        }
    }
    
    /// 앱에서 계속 사용할 핵심 데이터를 서버에서 새로 받아와 Store에 채운다.
    private func hydrateStoresAfterLogin() async {
        await runRecordStore.refresh()
        await userStore.refresh()
        await friendStore.refresh()
    }
}
