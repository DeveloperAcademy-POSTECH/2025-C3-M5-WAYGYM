//
//  ModuleFactory.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/8/26.
//

import SwiftUI

protocol ModuleFactoryProtocol {
    func makeMainView() -> MainView
    func makeProfileView() -> ProfileView
}

final class ModuleFactory: ModuleFactoryProtocol {
    static let shared = ModuleFactory()
    private init() {}

    func makeMainView() -> MainView {
        let viewModel = MainViewModel()
        let view = MainView(viewModel: viewModel, locationManager: LocationManager())
        return view
    }

    func makeProfileView() -> ProfileView {
        let view = ProfileView()
        return view
    }
}
