//
//  ControlPanelView.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/14/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct ControlPanelView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var isSimulating: Bool
    let startAction: () -> Void
    let stopAction: () -> Void
    let moveToCurrentLocationAction: () -> Void
    let loadCapturedPolygons: () -> Void
    @Binding var isCountingDown: Bool
    @Binding var countdown: Int
    @Binding var showResultModal: Bool
    @Binding var isAreaActive: Bool
    
    @State private var isLocationActive = false
    @State private var isHolding: Bool = false
    @State private var holdProgress: CGFloat = 0.0
    @State private var showTipBox: Bool = false
    @State private var backupPolylines: [MKPolyline] = []
    
    // let runRecordService = RunRecordService()
    
    var body: some View {
        ZStack {
            if showTipBox {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 350, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                    
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.yellow)
                        .frame(width: 350 * holdProgress, height: 50)
                    
                    Text("길게 눌러서 땅따먹기 종료")
                        .foregroundColor(.white)
                        .font(.title02)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 36)
                }
                .padding(.horizontal, 34)
                .padding(.top, 20)
                .position(x: UIScreen.main.bounds.width / 2, y: 120)
                .ignoresSafeArea()
                .zIndex(1)
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    if !isSimulating {
                        VStack(spacing: 25) {
                            VStack(spacing: 12) {
                                Button(
                                    action: {
                                        moveToCurrentLocationAction()
                                        isLocationActive.toggle()
                                    }) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isLocationActive ? Color.yellow : Color.black)
                                            .frame(width: 56, height: 56)
                                            .overlay(
                                                Image(systemName: "location.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 26, height: 26)
                                                    .foregroundColor(
                                                        isLocationActive ? .black : .yellow
                                                    )
                                            )
                                    }
                                
                                Text("내 위치")
                                    .font(.text02)
                                    .foregroundColor(isLocationActive ? .yellow : .white)
                            }
                            
                            VStack(spacing: 12) {
                                Button(
                                    action: {
                                        isAreaActive.toggle()
                                        if isAreaActive {
                                            backupPolylines = locationManager.polylines
                                            locationManager.polylines.removeAll()
                                            loadCapturedPolygons()
                                            print("Polylines cleared: \(locationManager.polylines.isEmpty)")
                                            // Firestore 리스너 재호출로 polylines 방지
                                            locationManager.fetchRunRecordsFromFirestore()
                                        } else {
                                            locationManager.polygons.removeAll()
                                            locationManager.polylines = backupPolylines
                                            print("Polylines restored: \(locationManager.polylines.count)")
                                            locationManager.fetchRunRecordsFromFirestore()
                                        }
                                    }) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isAreaActive ? Color.yellow : Color.black)
                                            .frame(width: 56, height: 56)
                                            .overlay(
                                                Image(systemName: "map.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 26, height: 26)
                                                    .foregroundColor(
                                                        isAreaActive ? .black : .yellow
                                                    )
                                            )
                                    }
                                Text("차지한\n영역")
                                    .multilineTextAlignment(.center)
                                    .font(.text02)
                                    .foregroundColor(isAreaActive ? .yellow : .white)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    if isSimulating {
                        VStack {
                            Button(
                                action: {
                                    moveToCurrentLocationAction()
                                    isLocationActive.toggle()
                                }) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isLocationActive ? Color.yellow : Color.black)
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: "location.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 26, height: 26)
                                                .foregroundColor(
                                                    isLocationActive ? .black : .yellow
                                                )
                                        )
                                }
                            
                            Text("내 위치")
                                .font(.text02)
                                .foregroundColor(isLocationActive ? .yellow : .white)
                        }
                        .padding(.trailing, 16)
                    }
                }
                
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if !isSimulating && !isCountingDown {
                            isCountingDown = true
                            countdown = 3
                            startCountdown()
                            print("재생 버튼 눌림")
                        }
                    }) {
                        if isSimulating {
                            Circle()
                                .fill(isHolding ? Color.yellow : Color.white)
                                .frame(width: 86, height: 86)
                                .overlay(
                                    Text("◼️")
                                        .font(.system(size: 38))
                                        .foregroundColor(.black)
                                )
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if isSimulating && !isHolding {
                                                isHolding = true
                                                showTipBox = true
                                                startFilling()
                                            }
                                        }
                                        .onEnded { _ in
                                            isHolding = false
                                            holdProgress = 0.0
                                            showTipBox = false
                                            if holdProgress >= 1.0 {
                                                showResultModal = true
                                            } else {
                                                holdProgress = 0.0
                                            }
                                        }
                                )
                        } else {
                            Image("startButton")
                                .resizable()
                                .frame(width: 86, height: 86)
                        }
                        
                    }
                    Spacer()
                }
            }
        }
    }
    
    func startCountdown() {
        guard !isSimulating else {
            print("⛔️ 이미 시뮬레이션 중이므로 countdown 시작 안 함")
            return
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown == 0 {
                timer.invalidate()
                isCountingDown = false
                isSimulating = true
                startAction()

                print("✅ startCountdown 실행됨")
            }
        }
    }
    
    func startFilling() {
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if isHolding {
                holdProgress += 0.03
                if holdProgress >= 1.0 {
                    timer.invalidate()
                    holdProgress = 1.0
                    showTipBox = false
                    stopAction()

                    isCountingDown = false
                    countdown = 3
                    showResultModal = true
                }
            } else {
                timer.invalidate()
                holdProgress = 0.0
            }
        }
    }
}
