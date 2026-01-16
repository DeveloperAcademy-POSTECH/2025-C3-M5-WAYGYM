//
//  SwipeBackUtils.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/16/26.
//

import Foundation
import SwiftUI
import UIKit

extension View {
    /// 버튼 탭 시 햅틱 피드백 추가
    func hapticFeedback(_ style: HapticStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                style.trigger()
            }
        )
    }
    
    /// 텍스트 입력 중 화면을 탭하면 키보드 내리기
    func dismissKeyboard() -> some View {
        self
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            })
    }
    
    /// 네비게이션 백버튼 숨기기
    func backHiddenSwipeEnabled() -> some View {
        self.modifier(BackHiddenSwipeEnabled())
    }
}


struct BackHiddenSwipeEnabled: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .background(EnableSwipeBackGesture())
    }
}

struct EnableSwipeBackGesture: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            controller.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            controller.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
