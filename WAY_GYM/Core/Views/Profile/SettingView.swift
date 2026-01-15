//
//  SettingView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI
import FirebaseAuth

struct SettingView: View {
    var body: some View {
        ZStack {
            Color.gang_bg_profile
                .ignoresSafeArea()
            
            VStack {
                Text("로그아웃")
                    .underline()
                    .font(.text02)
                    .foregroundStyle(Color.gangText2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture {
                        do {
                            try Auth.auth().signOut()
                        } catch {
                            print("[Logout Error]", error.localizedDescription)
                        }
                    }
            }
        }
    }
}

#Preview {
    SettingView()
}
