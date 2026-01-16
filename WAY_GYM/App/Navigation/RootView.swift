//
//  RootView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum AppEntryState {
    case auth
    case profileSetup
    case main
}

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
    @State private var entryState: AppEntryState = .auth

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Group {
                switch entryState {
                case .auth:
                    moduleFactory.makeAuthView {
                        Task { await decideEntryAfterAuth() }
                    }

                case .profileSetup:
                    moduleFactory.makeProfileSetupView()

                case .main:
                    moduleFactory.makeMainView()
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
                Task { await decideEntryAfterAuth() } // 앱 시작 직후 1회
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
            entryState = .auth
            coordinator.replaceRoot(.auth)
            return
        }

        let doc = Firestore.firestore().collection("Users").document(uid)
        do {
            let snapshot = try await doc.getDocument()
            if snapshot.exists {
                entryState = .main
                coordinator.replaceRoot(.main)
            } else {
                entryState = .profileSetup
                coordinator.replaceRoot(.profileSetup)
            }
        } catch {
            // 조회 실패 시: 일단 프로필 세팅으로 보내고, 이후 저장/재시도 UX로 처리
            entryState = .profileSetup
            coordinator.replaceRoot(.profileSetup)
        }
    }
}
