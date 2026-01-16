//
//  RootView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore


struct RootView: View {
    @EnvironmentObject
    private var coordinator: AppCoordinator
    private let moduleFactory: ModuleFactoryProtocol

    init(
        moduleFactory: ModuleFactoryProtocol
    ) {
        self.moduleFactory = moduleFactory
    }

    @State private var authListener: AuthStateDidChangeListenerHandle?

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Group {
                switch coordinator.root {
                case .auth:
                    moduleFactory.makeAuthView {
                        Task { await decideEntryAfterAuth() }
                    }

                case .profileSetup:
                    moduleFactory.makeProfileSetupView()

                case .main:
                    moduleFactory.makeMainView()

                case .profile:
                    moduleFactory.makeProfileView()

                case .setting:
                    moduleFactory.makeSettingView()
                }
            }
            .navigationDestination(for: AppRouter.self) { route in
                switch route {
                case .auth:
                    moduleFactory.makeAuthView {
                        Task { await decideEntryAfterAuth() }
                    }

                case .profileSetup:
                    moduleFactory.makeProfileSetupView()

                case .main:
                    moduleFactory.makeMainView()

                case .profile:
                    moduleFactory.makeProfileView()

                case .setting:
                    moduleFactory.makeSettingView()
                }
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
    }
    
    @MainActor
    func decideEntryAfterAuth() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            coordinator.replaceRoot(.auth)
            return
        }

        let doc = Firestore.firestore().collection("Users").document(uid)
        do {
            let snapshot = try await doc.getDocument()
            if snapshot.exists {
                coordinator.replaceRoot(.main)
            } else {
                coordinator.replaceRoot(.profileSetup)
            }
        } catch {
            // 조회 실패 시: 일단 프로필 세팅으로 보내고, 이후 저장/재시도 UX로 처리
            coordinator.replaceRoot(.profileSetup)
        }
    }
}
