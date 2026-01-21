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
    
    case friend
    case friendRequest
    
    case profile
    case setting
    
    case weaponList
    case minionList
    case runningList
    case runningDetail(String)
    
    case profileEdit
}

protocol ModuleFactoryProtocol {
    func make(_ route: AppRouter) -> AnyView
}

final class ModuleFactory: ModuleFactoryProtocol {
    static let shared = ModuleFactory()
    private init() {}
    
    func make(_ route: AppRouter) -> AnyView {
        switch route {
        case .auth:
            let viewModel = AuthViewModel()
            let view = AuthView(vm: viewModel)
            return AnyView(view)
        case .profileSetup:
            return AnyView(ProfileSetupView())
        case .main:
            let viewModel = MainViewModel()
            let view = MainView(vm: viewModel, locationManager: LocationManager())
            return AnyView(view)
        case .friend:
            return AnyView(FriendView())
        case .friendRequest:
            return AnyView(FriendRequestView())
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
        case .profileEdit:
            return AnyView(ProfileEditView())
        }
    }
}
