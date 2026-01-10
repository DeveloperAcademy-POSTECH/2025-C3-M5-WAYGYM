//
//  AppCoordinator.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/8/26.
//

import Combine
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
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

    /// 현재 화면을 새로운 화면으로 바꿀 때
    func replaceLast(with route: AppRouter) {
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(route)
    }
}
