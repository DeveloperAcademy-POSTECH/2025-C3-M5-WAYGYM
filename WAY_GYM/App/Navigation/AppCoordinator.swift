//
//  AppCoordinator.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/8/26.
//

import Combine
import Foundation
import SwiftUI

enum AppRouter: Hashable {
    case auth
    case profileSetup
    case main
    case profile
    case setting
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var root: AppRouter = .auth
    @Published var path: [AppRouter] = []

    /// 다음 화면
    func push(_ route: AppRouter) {
        path.append(route)
    }

    /// 이전 화면
    func pop(_ steps: Int = 1) {
        guard steps > 0, !path.isEmpty else { return }
        let stepsToRemove = min(steps, path.count)
        path.removeLast(stepsToRemove)
    }

    /// path에 쌓여있는 모든 화면을 지우고 루트로 돌아가기
    func popToRoot() {
        path.removeLast(path.count)
    }

    /// path에 쌓인 모든 화면을 지우고, 지정한 route 화면을 새로운 루트 화면으로 교체
    func replaceRoot(_ route: AppRouter) {
        root = route
        path.removeAll()
    }
}
