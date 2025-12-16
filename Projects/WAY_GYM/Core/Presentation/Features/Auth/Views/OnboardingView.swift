//
//  FirstInfoView.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/28/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import CoreLocation

struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @State private var name: String = ""
    @State private var gender: String = "남성"
    @State private var birthDate: Date = Date()
    @State private var height: String = ""
    @State private var weight: String = ""
    
    @State private var region: String = ""
    @State private var regionSource: RegionSource = .none
    @State private var showCitySheet: Bool = false
    @State private var showTownSheet: Bool = false
    
    @StateObject private var locationVM = AddressPickerViewModel()
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Text("기본정보")) {
                    TextField("이름", text: $name)
                    Picker("성별", selection: $gender) {
                        Text("남성").tag("남성")
                        Text("여성").tag("여성")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    DatePicker("생년월일", selection: $birthDate, displayedComponents: .date)
                    TextField("키 (cm)", text: $height)
                        .keyboardType(.decimalPad)
                    TextField("몸무게 (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("지역")) {
                    HStack {
                        Text(region.isEmpty ? "-" : region)
                        
                        Spacer()
                        
                        Button {
                            regionSource = .location
                            locationManager.moveToCurrentLocation()
                            if let loc = locationManager.currentLocation {
                                let clLocation = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                                fetchRegionName(from: clLocation)
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .foregroundStyle(Color.blue)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                        .onReceive(locationManager.$currentLocation) { location in
                            guard let loc = location else { return }
                            // 사용자가 Picker로 선택한 뒤에는 자동 위치 업데이트가 region을 덮어쓰지 않도록 방지
                            if regionSource == .picker && !region.isEmpty { return }
                            let clLocation = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                            fetchRegionName(from: clLocation)
                        }
                    }
                    
                    HStack {
                        // 1단계: 시/도
                        Menu {
                            Picker("시/도 선택", selection: $locationVM.selectedProvinceIndex) {
                                ForEach(locationVM.provinces.indices, id: \.self) { idx in
                                    Text(locationVM.provinces[idx].name).tag(idx)
                                }
                            }
                            .onChange(of: locationVM.selectedProvinceIndex) { _, _ in
                                // 상위가 바뀌면 자동으로 하위가 리셋되도록 ViewModel didSet에서 처리
                                regionSource = .picker
                                let composed = locationVM.composedAddress
                                if !composed.isEmpty { region = composed }
                            }
                        } label: {
                            HStack {
                                Text(locationVM.selectedProvince?.name ?? "시/도 선택")
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .foregroundStyle(Color.black)
                            .padding()
                        }

                        // 2단계: 시/군/구 (긴 목록 안정화를 위해 .sheet + List 사용)
                        Button {
                            showCitySheet = true
                        } label: {
                            HStack {
                                Text(locationVM.selectedCity?.name ?? "시/군/구 선택")
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(Color.black)
                            .padding()
                        }
                        .disabled(locationVM.selectedProvince == nil)
                        .sheet(isPresented: $showCitySheet) {
                            NavigationView {
                                List {
                                    let cities = locationVM.selectedProvince?.cities ?? []
                                    ForEach(cities.indices, id: \.self) { idx in
                                        Button {
                                            if locationVM.selectedCityIndex != idx {
                                                locationVM.selectedCityIndex = idx
                                                regionSource = .picker
                                                let composed = locationVM.composedAddress
                                                if !composed.isEmpty { region = composed }
                                            }
                                            showCitySheet = false
                                        } label: {
                                            HStack {
                                                Text(cities[idx].name)
                                                if idx == locationVM.selectedCityIndex {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                                .navigationTitle("시/군/구 선택")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("닫기") { showCitySheet = false }
                                    }
                                }
                            }
                        }

                        // 3단계: 읍/면/동/리 (긴 목록 안정화를 위해 .sheet + List 사용)
                        Button {
                            showTownSheet = true
                        } label: {
                            HStack {
                                Text(locationVM.selectedTown ?? "읍/면/동/리 선택")
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(Color.black)
                            .padding()
                        }
                        .disabled(locationVM.selectedCity == nil)
                        .sheet(isPresented: $showTownSheet) {
                            NavigationView {
                                List {
                                    let towns = locationVM.selectedCity?.towns ?? []
                                    ForEach(towns.indices, id: \.self) { idx in
                                        Button {
                                            if locationVM.selectedTownIndex != idx {
                                                locationVM.selectedTownIndex = idx
                                                regionSource = .picker
                                                let composed = locationVM.composedAddress
                                                if !composed.isEmpty { region = composed }
                                            }
                                            showTownSheet = false
                                        } label: {
                                            HStack {
                                                Text(towns[idx])
                                                if idx == locationVM.selectedTownIndex {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                                .navigationTitle("읍/면/동/리 선택")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("닫기") { showTownSheet = false }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Button {
                saveUser()
            } label: {
                Text("확인")
                    .foregroundStyle(Color.black)
            }
        }
        .task {
            if locationVM.provinces.isEmpty {
                locationVM.load()
            }
            if region.isEmpty { regionSource = .location }
        }
    }
    
    func fetchRegionName(from location: CLLocation) {
        // 위치를 받아서 역지오코딩으로 region 문자열 설정
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { placemarks, error in
            if let place = placemarks?.first, error == nil {
                if let shortRegion = locationManager.extractRegionName(from: place) {
                    if !(regionSource == .picker && !self.region.isEmpty) {
                        self.region = shortRegion  // 예: "처인구 모현읍" 또는 "마포구 신수동"
                    }
                } else {
                    // placemark에서 정보 추출 실패 시, 전체 주소 문자열 활용
                    if let lines = place.addressDictionary?["FormattedAddressLines"] as? [String],
                       let fullAddress = lines.first {
                        let trimmed = fullAddress.replacingOccurrences(of: "대한민국 ", with: "")
                        let comps = trimmed.split(separator: " ").map(String.init)

                        var guGun: String?
                        var dem: String? // 동/읍/면
                        for token in comps {
                            if guGun == nil && (token.hasSuffix("구") || token.hasSuffix("군")) {
                                guGun = token
                            }
                            if dem == nil && (token.hasSuffix("동") || token.hasSuffix("읍") || token.hasSuffix("면")) {
                                dem = token
                            }
                        }

                        if let g = guGun, let d = dem {
                            if !(regionSource == .picker && !self.region.isEmpty) {
                                self.region = "\(g) \(d)"
                            }
                        } else if let city = place.locality, city != place.administrativeArea, let d = dem {
                            if !(regionSource == .picker && !self.region.isEmpty) {
                                self.region = "\(city) \(d)"
                            }
                        }
                    }
                }
            } else {
                print("Geocoding failed: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
    
    func saveUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let calendar = Calendar.current
        let ymd = calendar.dateComponents([.year, .month, .day], from: birthDate)
        let birthDateOnly = calendar.date(from: ymd) ?? birthDate
        let user = UserModel(
            id: uid,
            name: name,
            birthDate: birthDateOnly,
            height: Double(height) ?? 0,
            weight: Double(weight) ?? 0,
            gender: gender,
            region: region
        )
        
        let db = Firestore.firestore()
        do {
            try db.collection("Users").document(uid).setData(from: user) { error in
                if let error = error {
                    print("❌ Error saving user: \(error.localizedDescription)")
                } else {
                    let docRef = db.collection("Users").document(uid)
                    docRef.getDocument { snapshot, fetchError in
                        if let fetchError = fetchError {
                            print("❌ Fetch after save failed: \(fetchError.localizedDescription)")
                            DispatchQueue.main.async {
                                router.currentScreen = .main(id: UUID())
                            }
                            return
                        }
                        guard let snapshot = snapshot, snapshot.exists else {
                            print("❌ No snapshot after save")
                            DispatchQueue.main.async {
                                router.currentScreen = .main(id: UUID())
                            }
                            return
                        }
                        do {
                            let fetchedUser = try snapshot.data(as: UserModel.self)
                            LocalUserStore.save(fetchedUser)
                            print("✅ User saved locally")
                        } catch {
                            print("❌ Decoding error after fetch: \(error)")
                        }
                        DispatchQueue.main.async {
                            router.currentScreen = .main(id: UUID())
                        }
                    }
                }
            }
        } catch {
            print("❌ Encoding error: \(error)")
        }
    }
}



#Preview {
    OnboardingView()
}
