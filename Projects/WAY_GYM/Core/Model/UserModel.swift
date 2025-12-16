//
//  UserModel.swift
//  Ch3Personal
//
//  Created by 이주현 on 5/30/25.
//

import Foundation

struct UserModel: Codable, Identifiable {
    var id: String  // uid
    var name: String
    var birthDate: Date
    var height: Double
    var weight: Double
    var gender: String   // "남성" 또는 "여성"
    var region: String   // 예: "마포구 용강동" / "처인구 모현읍"
}

// 로컬에 저장하는 모델
struct LocalUser: Codable {
    let id: String
    let name: String
    let birthDate: Date
    let height: Double
    let weight: Double
    let gender: String
    let region: String
}

enum LocalUserStore {
    private static let key = "local_user_v1"

    static func save(_ user: UserModel) {
        let local = LocalUser(
            id: user.id,
            name: user.name,
            birthDate: user.birthDate,
            height: user.height,
            weight: user.weight,
            gender: user.gender,
            region: user.region
        )
        do {
            let data = try JSONEncoder().encode(local)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("❌ Local encode error: \(error)")
        }
    }

    static func load() -> LocalUser? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(LocalUser.self, from: data)
        } catch {
            print("❌ Local decode error: \(error)")
            return nil
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
