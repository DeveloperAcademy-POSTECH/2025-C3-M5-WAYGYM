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

    init(
        moduleFactory: ModuleFactoryProtocol
    ) {
        self.moduleFactory = moduleFactory
    }

    @State private var isLoggedIn: Bool = Auth.auth().currentUser != nil
    @State private var authListener: AuthStateDidChangeListenerHandle?

    var body: some View {
        Group {
            if isLoggedIn {
                NavigationStack(
                    path: Binding(
                        get: { coordinator.path },
                        set: { coordinator.path = $0 }
                    )
                ) {
                    moduleFactory.makeMainView()
                        .navigationBarBackButtonHidden(true)
                        .navigationDestination(for: AppRouter.self) { route in
                            switch route {
                            case .main:
                                moduleFactory.makeMainView()
                            case .profile:
                                moduleFactory.makeProfileView()
                            case .setting:
                                moduleFactory.makeSettingView()
                            }
                        }
                }
            } else {
                moduleFactory.makeAuthView(onAuthed: {
                    coordinator.path.removeAll()
                    isLoggedIn = true
                })
            }
        }
        .onAppear {
            authListener = Auth.auth().addStateDidChangeListener { _, user in
                isLoggedIn = (user != nil)
                if user == nil {
                    coordinator.path.removeAll()
                }
            }
        }
        .onDisappear {
            if let authListener {
                Auth.auth().removeStateDidChangeListener(authListener)
            }
        }
    }
}

