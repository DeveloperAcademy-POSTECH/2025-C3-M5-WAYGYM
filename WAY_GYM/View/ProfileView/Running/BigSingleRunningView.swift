//
//  BigSingleRunningView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/4/25.
//

import SwiftUI
import MapKit

struct BigSingleRunningView: View {
    let summary: RunSummary
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            //:: 추후 수정
            Image("SampleMap")
                .resizable()
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack {
                    HStack {
                        customLabel(value: "\(Int(summary.capturedArea))", title:
                                        "영역(m²)")
                        
                        Spacer()
                        
                        VStack() {
                            // Text(summary.startTime.formattedYMD())
                            // Text("\(summary.startTime.formattedHM()) (\(summary.startTime.koreanWeekday()))")
                        }
                            .font(.text01)
                            .padding(.trailing, 16)
                    }
                    
                    Spacer()
                        .frame(height: 24)
                    
                    HStack {
                        customLabel(value: "\(Int(summary.duration) / 60):\(String(format: "%02d", Int(summary.duration) % 60))", title: "소요시간")
                        Spacer()
                        customLabel(value: String(format: "%.2f", summary.distance / 1000), title: "거리(km)")
                        Spacer()
                        // customLabel(value: String(Int(summary.calories)), title: "칼로리")
                    }
                }
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(width: UIScreen.main.bounds.width)
                // .frame(height: 150)
                .frame(height: UIScreen.main.bounds.height * 0.21)
                .background(Color.gang_sheet_bg_opacity)
                .cornerRadius(16)
                
            }
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image("xmark")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color.gang_text_2)
                            .padding(15)
                            .background(Circle().foregroundStyle(Color.gang_bg))
                    }
                }
                .padding(.horizontal, 16)
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    struct customLabel: View {
        let value: String
        let title: String
        
        var body: some View {
            VStack {
                Text(value)
                    .font(.title01)
                Text(title)
                    .font(.title03)
            }
            .padding(.horizontal, 16)
        }
    }
}

//#Preview {
//    BigSingleRunningView(summary: RunSummary)
//        .foregroundColor(Color.gang_text_2)
//        .font(.title01)
//}
