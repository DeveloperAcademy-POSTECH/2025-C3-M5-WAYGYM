//
//  RootView.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject
    private var coordinator: AppCoordinator
    private let moduleFactory: ModuleFactoryProtocol

    init(
        moduleFactory: ModuleFactoryProtocol
    ) {
        self.moduleFactory = moduleFactory
    }

    var body: some View {
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
                    }
                }
        }
    }
}

