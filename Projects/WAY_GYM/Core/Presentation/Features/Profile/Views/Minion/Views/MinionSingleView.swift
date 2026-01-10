//
//  MinionSingleView.swift
//  Ch3Personal
//
//  Created by 이주현 on 5/31/25.
//

import SwiftUI

struct MinionSingleView: View {
    let minionIndex: Int
    @StateObject private var vm: MinionSingleViewModel
    
    init(minionIndex: Int) {
        self.minionIndex = minionIndex
        _vm = StateObject(wrappedValue: MinionSingleViewModel(minionIndex: minionIndex))
    }
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.gang_bg_primary_4
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.gang_text_2)
                            .font(.system(size: 30))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(25)
            
            VStack {
                ZStack {
                    Image("Flash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 220)
                    
                    Image(vm.minion.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200)
                        .padding(.bottom, -20)
                }
                .padding(.bottom, 20)
                
                
                VStack(spacing: 16) {
                    HStack {
                        Text(vm.minion.name)
                        Spacer()
                        Text(String(format: "%.0f km", vm.minion.unlockNumber))
                    }
                    .padding(.horizontal, 10)
                    
                    Text(vm.minion.description)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Spacer()
                        
                        if let date = vm.acquisitionDate {
                            Text("\(formatShortDate(date))")
                                .font(.text01)
                        }
                    }
                }
                .padding(20)
                .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gang_bg_secondary_2, lineWidth: 3)
                    )
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            vm.load()
        }
        .navigationBarBackButtonHidden(true)
    }
}
