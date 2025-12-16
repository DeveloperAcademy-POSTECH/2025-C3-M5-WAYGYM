//
//  AppRouter.swift
//  WAY_GYM
//
//      Created by soyeonsoo on 6/2/25.
//

import Foundation
import SwiftUI

class AppRouter: ObservableObject {
    @Published var currentScreen: AppScreen = .main(id: UUID())
}
