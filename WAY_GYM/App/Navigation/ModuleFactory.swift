//
//  ModuleFactory.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/8/26.
//

import SwiftUI

enum AppRouter: Hashable {
    case auth
    case profileSetup
    case main
    case profile
    case setting
    
    case weaponList
    case minionList
    case runningList
    case runningDetail(String)
}

protocol ModuleFactoryProtocol {
    func make(_ route: AppRouter, onAuthed: @escaping () -> Void) -> AnyView
}

final class ModuleFactory: ModuleFactoryProtocol {
    static let shared = ModuleFactory()
    private init() {}
    
    func make(_ route: AppRouter, onAuthed: @escaping () -> Void) -> AnyView {
        switch route {
        case .auth:
            return AnyView(AuthView(onAuthed: onAuthed))
        case .profileSetup:
            return AnyView(ProfileSetupView())
        case .main:
            let viewModel = MainViewModel()
            let view = MainView(vm: viewModel, locationManager: LocationManager())
            return AnyView(view)
        case .profile:
            return AnyView(ProfileView())
        case .setting:
            return AnyView(SettingView())
        case .weaponList:
            return AnyView(WeaponListView())
        case .minionList:
            return AnyView(MinionListView())
        case .runningList:
            return AnyView(RunningListView())
        case .runningDetail(let runId):
            return AnyView(BigSingleRunningView(runId: runId))
        }
    }
}
