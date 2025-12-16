//
//  AppRouter.swift
//  WAY_GYM
//
//      Created by soyeonsoo on 6/2/25.
//

import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AppScreen {
    case auth // 첫 진입 시, 키체인 만료 시
    case onboarding // 첫 진입 시 - 키.몸무게 설정
    case main(id: UUID = UUID())
    case profile
}

class AppRouter: ObservableObject {
    @Published var currentScreen: AppScreen = .main(id: UUID())
}

struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var locationManager = LocationManager()
    @State private var authHandle: AuthStateDidChangeListenerHandle?
    
    var body: some View {
        NavigationStack {
            switch router.currentScreen {
            case .auth: PhoneAuthView()
                
            case .onboarding: OnboardingView()
                    .foregroundStyle(Color.black)
                    .tint(.black)
                
            case .main(let id):
                        MainView(locationManager: locationManager)
                            .id(id)
                            .environmentObject(LocationManager())

            case .profile:
                AnyView( ProfileView()
                        .environmentObject(RunRecordService())
                        .font(.text01)
                        .foregroundColor(Color("gang_text_2"))
                        .navigationBarHidden(true)
                )
            }
        }
        .task {
            let user = Auth.auth().currentUser
            routeAfterAuth(user, router: router)
            
            authHandle = Auth.auth().addStateDidChangeListener { _, user in
                routeAfterAuth(user, router: router)
            }
        }
        
    }
}

extension RootView {
    func routeAfterAuth(_ user: User?, router: AppRouter) {
        guard let user, let uid = user.uid as String? else {
            router.currentScreen = .auth
            return
        }
        
        let db = Firestore.firestore()
        db.collection("Users").document(uid).getDocument { snapshot, error in
            if let doc = snapshot, doc.exists {
                router.currentScreen = .main(id: UUID())
            } else {
                router.currentScreen = .onboarding
            }
        }
    }
}
