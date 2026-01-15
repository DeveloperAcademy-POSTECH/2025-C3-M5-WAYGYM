//
//  Country.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/14/26.
//

import SwiftUI

struct Country: Identifiable, Hashable {
    let id: String       // ISO code (e.g. "KR")
    let name: String     // display name
    let dialCode: String // e.g. "+82"
    let flag: String     // emoji flag
}

enum CountryData {
    static let all: [Country] = [
        .init(id: "KR", name: "대한민국", dialCode: "+82", flag: "🇰🇷"),
        .init(id: "US", name: "United States", dialCode: "+1", flag: "🇺🇸"),
        .init(id: "JP", name: "日本", dialCode: "+81", flag: "🇯🇵"),
        .init(id: "CN", name: "中国", dialCode: "+86", flag: "🇨🇳"),
        .init(id: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧"),
        .init(id: "AU", name: "Australia", dialCode: "+61", flag: "🇦🇺"),
        .init(id: "SG", name: "Singapore", dialCode: "+65", flag: "🇸🇬"),
    ]

    static let korea: Country = all.first(where: { $0.id == "KR" })!
}

struct CountryPickerSheet: View {
    @State private var query: String = ""
    let selected: Country
    let onSelect: (Country) -> Void

    var filtered: [Country] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return CountryData.all }
        let q = query.lowercased()
        return CountryData.all.filter {
            $0.name.lowercased().contains(q) ||
            $0.id.lowercased().contains(q) ||
            $0.dialCode.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { c in
                Button {
                    onSelect(c)
                } label: {
                    HStack(spacing: 12) {
                        Text(c.flag).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name)
                                .font(.system(size: 16))
                            Text("\(c.id)  \(c.dialCode)")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if c == selected {
                            Image(systemName: "checkmark").foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .foregroundStyle(Color.gangBlack)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { onSelect(selected) }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "국가/코드 검색")
        }
    }
}


enum PhoneKR {
    /// 숫자만 남기기
    static func digitsOnly(_ s: String) -> String {
        s.filter(\.isNumber)
    }

    /// 010-1234-5678 포맷
    static func formatKR(_ raw: String) -> String {
        let d = digitsOnly(raw)
        // 010xxxxxxxx 형태를 가정하고 점진 포맷
        if d.count <= 3 { return d }
        if d.count <= 7 {
            let a = d.prefix(3)
            let b = d.dropFirst(3)
            return "\(a)-\(b)"
        }
        let a = d.prefix(3)
        let b = d.dropFirst(3).prefix(4)
        let c = d.dropFirst(7).prefix(4)
        return "\(a)-\(b)-\(c)"
    }

    /// "010"으로 시작하는 11자리
    static func isValidKR(_ input: String) -> Bool {
        let d = digitsOnly(input)
        return d.count == 11 && d.hasPrefix("010")
    }

    /// 01012345678 -> +821012345678
    static func toE164KR(_ input: String) -> String? {
        guard isValidKR(input) else { return nil }
        let d = digitsOnly(input) // 01012345678
        let withoutLeadingZero = String(d.dropFirst(1)) // 1012345678
        return "+82" + withoutLeadingZero
    }
}

#Preview("CountryPickerSheet") {
    CountryPickerSheet(
        selected: CountryData.korea,
        onSelect: { _ in }
    )
}
