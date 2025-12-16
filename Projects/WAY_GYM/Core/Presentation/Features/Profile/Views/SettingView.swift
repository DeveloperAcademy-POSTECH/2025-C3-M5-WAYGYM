//
//  SettingView.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/25/25.
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var vm = SettingViewModel()

    var body: some View {
        ZStack {
            Color.gang_bg_profile
                .ignoresSafeArea()
            
            VStack {
                CustomNavigationBar(title: "설정")
                
                HStack {
                    Spacer()
                    if vm.isEditingProfile {
                        Button("취소") { vm.cancelEditing() }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1)
                            )
                        Button("저장") { vm.saveEdits() }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8).fill(Color.white)
                            )
                            .foregroundColor(.black)
                    } else {
                        Button {
                            vm.startEditing()
                        } label: {
                            Image(systemName: "pencil.line")
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 1)
                                )
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("프로필")
                        .font(.text02)
                    
                    if vm.isEditingProfile {
                        // Editable rows
                        ProfileRowView(title: "이름") {
                            TextField("이름", text: $vm.editName)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .tint(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        ProfileRowView(title: "성별") {
                            Picker("성별", selection: $vm.editGender) {
                                Text("남성").tag("남성")
                                Text("여성").tag("여성")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 220)
                        }
                        ProfileRowView(title: "생년월일") {
                            DatePicker("생년월일", selection: $vm.editBirthDate, displayedComponents: .date)
                                .labelsHidden()
                                .tint(.white)
                        }
                        ProfileRowView(title: "키 (cm)") {
                            TextField("예: 170", text: $vm.editHeight)
                                .keyboardType(.numberPad)
                                .tint(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        ProfileRowView(title: "몸무게 (kg)") {
                            TextField("예: 60", text: $vm.editWeight)
                                .keyboardType(.numberPad)
                                .tint(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        ProfileRowView(title: "지역") {
                            Text(vm.editRegion.isEmpty ? "-" : vm.editRegion)
                        }
                        
                        HStack {
                            // 1단계: 시/도
                            Menu {
                                Picker("시/도 선택", selection: $vm.locationVM.selectedProvinceIndex) {
                                    ForEach(vm.locationVM.provinces.indices, id: \.self) { idx in
                                        Text(vm.locationVM.provinces[idx].name).tag(idx)
                                    }
                                }
                                .onChange(of: vm.locationVM.selectedProvinceIndex) { _, _ in
                                    // 상위가 바뀌면 자동으로 하위가 리셋되도록 ViewModel didSet에서 처리
                                    vm.regionSource = .picker
                                    let composed = vm.locationVM.composedAddress
                                    if !composed.isEmpty { vm.editRegion = composed }
                                }
                            } label: {
                                HStack {
                                    Text(vm.locationVM.selectedProvince?.name ?? "시/도 선택")
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .padding()
                            }
                            
                            // 2단계: 시/군/구 (긴 목록 안정화를 위해 .sheet + List 사용)
                            Button {
                                vm.showCitySheet = true
                            } label: {
                                HStack {
                                    Text(vm.locationVM.selectedCity?.name ?? "시/군/구 선택")
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                }
                                .padding()
                            }
                            .disabled(vm.locationVM.selectedProvince == nil)
                            .sheet(isPresented: $vm.showCitySheet) {
                                NavigationView {
                                    List {
                                        let cities = vm.locationVM.selectedProvince?.cities ?? []
                                        ForEach(cities.indices, id: \.self) { idx in
                                            Button {
                                                if vm.locationVM.selectedCityIndex != idx {
                                                    vm.locationVM.selectedCityIndex = idx
                                                    vm.regionSource = .picker
                                                    let composed = vm.locationVM.composedAddress
                                                    if !composed.isEmpty { vm.editRegion = composed }
                                                }
                                                vm.showCitySheet = false
                                            } label: {
                                                HStack {
                                                    Text(cities[idx].name)
                                                        .foregroundStyle(Color.black)
                                                    if idx == vm.locationVM.selectedCityIndex {
                                                        Spacer()
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .navigationTitle("시/군/구 선택")
                                    .navigationBarTitleDisplayMode(.inline)
                                }
                            }
                            
                            // 3단계: 읍/면/동/리 (긴 목록 안정화를 위해 .sheet + List 사용)
                            Button {
                                vm.showTownSheet = true
                            } label: {
                                HStack {
                                    Text(vm.locationVM.selectedTown ?? "읍/면/동/리 선택")
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                }
                                .padding()
                            }
                            .disabled(vm.locationVM.selectedCity == nil)
                            .sheet(isPresented: $vm.showTownSheet) {
                                NavigationView {
                                    List {
                                        let towns = vm.locationVM.selectedCity?.towns ?? []
                                        ForEach(towns.indices, id: \.self) { idx in
                                            Button {
                                                if vm.locationVM.selectedTownIndex != idx {
                                                    vm.locationVM.selectedTownIndex = idx
                                                    vm.regionSource = .picker
                                                    let composed = vm.locationVM.composedAddress
                                                    if !composed.isEmpty { vm.editRegion = composed }
                                                }
                                                vm.showTownSheet = false
                                            } label: {
                                                HStack {
                                                    Text(towns[idx])
                                                        .foregroundStyle(Color.black)
                                                    if idx == vm.locationVM.selectedTownIndex {
                                                        Spacer()
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Read-only rows
                        ProfileRowView(title: "이름", value: vm.localUser?.name ?? "-")
                        ProfileRowView(title: "성별", value: vm.localUser?.gender.isEmpty == false ? vm.localUser!.gender : "-")
                        ProfileRowView(title: "생년월일") {
                            if let date = vm.localUser?.birthDate {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                            } else {
                                Text("-")
                            }
                        }
                        ProfileRowView(title: "키 (cm)", value: vm.localUser.map { String(Int($0.height)) } ?? "-")
                        ProfileRowView(title: "몸무게 (kg)", value: vm.localUser.map { String(Int($0.weight)) } ?? "-")
                        ProfileRowView(title: "지역", value: vm.localUser?.region.isEmpty == false ? vm.localUser!.region : "-")
                    }
                }
                .padding()

                VStack(alignment: .leading, spacing: 12) {
                    if vm.isEditingProfile {
                        //
                    } else {
                        Text("로그인 정보")
                            .font(.text02)
                        
                        ProfileRowView(title: "전화번호") {
                            Text(vm.phoneNumberText)
    
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                Button {
                    vm.logout()
//                    DispatchQueue.main.async {
//                        router.currentScreen = .auth
//                    }
                } label: {
                    if vm.isEditingProfile {
                        //
                    } else {
                        Text("로그아웃")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                
            }
            .font(.text02)
            .foregroundStyle(Color.gang_text_2)
            .padding(.horizontal, 16)
        }
        .task {
            vm.onAppear()
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct ProfileRowView<Content: View>: View {
    let title: String
    @ViewBuilder let value: () -> Content

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.text_secondary)
            Spacer()
            value()
                .font(.text01)
        }
    }
}

extension ProfileRowView where Content == Text {
    init(title: String, value: String) {
        self.title = title
        self.value = { Text(value) }
    }
}


extension SettingView {
    /// Preview 전용 이니셜라이저. 외부에서 ViewModel을 주입해 미리보기에서 쉽게 설정할 수 있습니다.
    init(vm: @autoclosure @escaping () -> SettingViewModel) {
        _vm = StateObject(wrappedValue: vm())
    }
}

#Preview("SettingView") {
    let router = AppRouter()
    return SettingView(vm: SettingViewModel())
        .environmentObject(router)
        .preferredColorScheme(.dark)
}
