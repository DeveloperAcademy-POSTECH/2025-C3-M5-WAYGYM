//
//  Signin.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/22/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct PhoneAuthView: View {
    @EnvironmentObject var router: AppRouter
    
    struct Country: Identifiable, Hashable {
        let id: String  // ISO 코드 (예: KR, US)
        let name: String
        let dialCode: String // 국제 전화 코드 숫자만 (예: "82")
        let example: String  // 예시(국내 형식)
    }
    @State private var countries: [Country] = [
        Country(id: "KR", name: "대한민국", dialCode: "82", example: "01012345678"),
        Country(id: "US", name: "United States", dialCode: "1", example: "4155552671"),
        Country(id: "JP", name: "日本", dialCode: "81", example: "09012345678")
    ]
    @State private var selectedCountry: Country = Country(id: "KR", name: "대한민국", dialCode: "82", example: "01012345678")
    @State private var nationalNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var verificationID: String?
    @State private var message: String = ""
    @State private var isCodeSent: Bool = false
    @State private var isLoading: Bool = false
    @State private var isLoggedIn: Bool = false
    @State private var showCountrySheet: Bool = false
    @State private var countryPickerMode: Int = 0 // 0: wheel, 1: inline
    @State private var shouldCloseMenu: Bool = false

    // 숫자만 남기기
    private func digitsOnly(_ s: String) -> String {
        s.filter { $0.isNumber }
    }

    // 국가별 규칙으로 E.164 미리보기 생성
    private var e164Preview: String {
        let raw = digitsOnly(nationalNumber)
        switch selectedCountry.id {
        case "KR":
            // 한국: 국내 번호가 0으로 시작하면 제거 (예: 0101234 → 101234)
            let trimmed = raw.hasPrefix("0") ? String(raw.dropFirst()) : raw
            return trimmed.isEmpty ? "" : "+" + selectedCountry.dialCode + trimmed
        default:
            // 일반: 그대로 국제코드 붙이기
            return raw.isEmpty ? "" : "+" + selectedCountry.dialCode + raw
        }
    }
    
    // ISO 국가코드를 국기 이모지로 변환 (예: "KR" -> 🇰🇷)
    private func flagEmoji(_ countryCode: String) -> String {
        let base: UInt32 = 127397
        var scalarView = String.UnicodeScalarView()
        for u in countryCode.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(base + u.value) {
                scalarView.append(flagScalar)
            }
        }
        return String(scalarView)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("전화번호 인증 로그인")
                .font(.title)
                .padding(.top, 40)
            
            // 국가 선택 (Menu + Segmented Picker)
            Menu {
                Picker("국적 선택", selection: $selectedCountry) {
                    ForEach(countries) { c in
                        Text("\(flagEmoji(c.id)) \(c.name) (+\(c.dialCode))").tag(c)
                    }
                }
                .onChange(of: selectedCountry) { _ in
                    shouldCloseMenu.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("\(flagEmoji(selectedCountry.id)) \(selectedCountry.name) (+\(selectedCountry.dialCode))")
                        .foregroundStyle(Color.black)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .id(shouldCloseMenu)
            .padding(.horizontal, 32)

            // 국내 형식 입력
            TextField("전화번호 (예: \(selectedCountry.example))", text: $nationalNumber)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 32)
                .onChange(of: nationalNumber) { newValue in
                    nationalNumber = digitsOnly(newValue)
                }

            // 디버깅/가시화: Firebase 전송 번호(E.164)
            VStack(alignment: .leading, spacing: 6) {
                Text("서버 전송 번호 (E.164)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text(e164Preview.isEmpty ? "(미입력)" : e164Preview)
                        .font(.callout)
                        .foregroundColor(e164Preview.isEmpty ? .secondary : .blue)
                    Spacer()
                }
            }
            .padding(.horizontal, 32)
            
            if isCodeSent {
                TextField("SMS 인증번호", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 32)
            }
            
            if !isCodeSent {
                Button(action: sendCode) {
                    Text("인증번호 요청")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)
            } else {
                Button(action: logIn) {
                    Text("로그인")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)
            }
            
            if isLoading {
                ProgressView()
            }
            
            Text(message)
                .foregroundColor(.red)
                .padding()
            
            if isLoggedIn {
                Text("로그인 성공! 🎉").foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding(.bottom, 20)
    }

    func sendCode() {
        message = "인증 요청 중..."
        isLoading = true
        Auth.auth().languageCode = "ko"

        let e164 = e164Preview
        guard !e164.isEmpty else {
            isLoading = false
            message = "전화번호를 입력해주세요."
            return
        }

        PhoneAuthProvider.provider().verifyPhoneNumber(e164, uiDelegate: nil) { id, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    message = "에러: \(error.localizedDescription)"
                    return
                }
                verificationID = id
                UserDefaults.standard.set(id, forKey: "authVerificationID")
                message = "인증번호가 전송되었습니다. SMS를 확인해주세요.\n전송 번호: \(e164)"
                isCodeSent = true
            }
        }
    }

    func logIn() {
        guard let verificationID = verificationID ?? UserDefaults.standard.string(forKey: "authVerificationID") else {
            message = "인증 ID를 찾을 수 없습니다."
            return
        }
        isLoading = true
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        Auth.auth().signIn(with: credential) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    message = "로그인 실패: \(error.localizedDescription)"
                } else {
                    message = "로그인 성공!"
                    isLoggedIn = true
                    
                    // 🔁 서버 사용자 문서 동기화 → 로컬 캐시 저장
                    let db = Firestore.firestore()
                    if let uid = result?.user.uid {
                        let docRef = db.collection("Users").document(uid)
                        docRef.getDocument { snapshot, fetchError in
                            if let fetchError = fetchError {
                                print("❌ Fetch user after login failed: \(fetchError.localizedDescription)")
                                return
                            }
                            if let snapshot = snapshot, snapshot.exists {
                                // 이미 서버에 유저가 있으면 디코딩 후 로컬 저장
                                do {
                                    let fetched = try snapshot.data(as: UserModel.self)
                                    LocalUserStore.save(fetched)
                                    print("✅ Synced existing user to local cache")
                                } catch {
                                    print("❌ Decode error: \(error)")
                                }
                            } else {
                                // 서버에 유저가 없으면 기본 값으로 생성
                                let newUser = UserModel(
                                    id: uid,
                                    name: "",
                                    birthDate: Date(),
                                    height: 0,
                                    weight: 0,
                                    gender: "",
                                    region: ""
                                )
                                do {
                                    try docRef.setData(from: newUser) { setError in
                                        if let setError = setError {
                                            print("❌ Create user after login failed: \(setError.localizedDescription)")
                                            return
                                        }
                                        LocalUserStore.save(newUser)
                                        print("✅ Created user on server and cached locally")
                                    }
                                } catch {
                                    print("❌ Encoding error while creating user: \(error)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
}

struct PhoneAuthView_Previews: PreviewProvider {
    static var previews: some View {
        PhoneAuthView()
            .environmentObject(AppRouter())
    }
}


// MARK: - HomeView
struct HomeView: View {
    let userName: String
    let age: Int
    let weight: Double

    var body: some View {
        VStack(spacing: 16) {
            Text("홈")
                .font(.largeTitle)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("이름: \(userName)")
                Text("나이: \(age)")
                Text(String(format: "몸무게: %.1f kg", weight))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Spacer()
        }
        .padding()
        .navigationTitle("WAY_GYM")
    }
}
