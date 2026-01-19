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
                moduleFactory.make(coordinator.root) {
                    Task { await decideEntryAfterAuth() }
                }
            }
            .navigationDestination(for: AppRouter.self) { route in
                moduleFactory.make(route) {
                    Task { await decideEntryAfterAuth() }
                }
            }
            .task {
                await runRecordStore.refresh()
                await userStore.refresh()
                await friendStore.refresh()
            }
            .onAppear {
                authListener = Auth.auth().addStateDidChangeListener { _, _ in
                    Task { await decideEntryAfterAuth() }
                }
                Task { await decideEntryAfterAuth() }
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
            coordinator.replaceRoot(.auth)
            return
        }

        do {
            let exists = try await userRepository.doesUserExist(uid: uid)
            if exists {
                await runRecordStore.refresh()
                await userStore.refresh()
                await friendStore.refresh()
                coordinator.replaceRoot(.main)
            } else {
                await runRecordStore.refresh()
                await userStore.refresh()
                await friendStore.refresh()
                coordinator.replaceRoot(.profileSetup)
            }
        } catch {
            // 조회 실패 시: 일단 프로필 세팅으로 보내고, 이후 저장/재시도 UX로 처리
            await runRecordStore.refresh()
            await userStore.refresh()
            await friendStore.refresh()
            coordinator.replaceRoot(.profileSetup)
        }
    }
}
