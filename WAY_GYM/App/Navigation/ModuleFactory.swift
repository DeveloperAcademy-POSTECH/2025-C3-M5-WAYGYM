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
    func makeAuthView(onAuthed: @escaping () -> Void) -> AnyView
    func makeProfileSetupView() -> ProfileSetupView
    func makeSettingView() -> SettingView
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

    func makeAuthView(onAuthed: @escaping () -> Void) -> AnyView {
        AnyView(AuthView(onAuthed: onAuthed))
    }
    
    func makeProfileSetupView() -> ProfileSetupView {
        let view = ProfileSetupView()
        return view
    }
    
    func makeSettingView() -> SettingView {
        let view = SettingView()
        return view
    }
}
