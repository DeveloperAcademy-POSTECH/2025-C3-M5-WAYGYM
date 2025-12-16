//
//  AddressListPracticeView.swift
//  WAY_GYM
//
//  Created by 이주현 on 9/28/25.
//

import SwiftUI

// 시/도
struct Province: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let cities: [City] // 시/군/구
}

// 시/군/구
struct City: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let towns: [String] // 읍/면/동/리
}

// MARK: - Address Loader

enum AddressLoadError: Error {
    case fileNotFound
    case decodeFailed
}

/// JSONSerialization으로 파싱 후 정규화
final class AddressLoader {
    static func loadFromBundle(fileName: String = "3depth", fileExtension: String = "json") throws -> [Province] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            throw AddressLoadError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let jsonObj = try JSONSerialization.jsonObject(with: data, options: []) // top-level: [String: Any]
        guard let root = jsonObj as? [String: Any] else { throw AddressLoadError.decodeFailed }

        // 1단계: 시/도
        var provinces: [Province] = []
        for (rawProvinceName, rawCities) in root {
            let provinceName = rawProvinceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !provinceName.isEmpty else { continue }

            var cities: [City] = []

            switch rawCities {
            case let dict as [String: Any]:
                // 일반 케이스: "시/군/구" : [읍/면/동 ...] 또는 또 다른 딕셔너리
                for (rawCityName, rawTowns) in dict {
                    let cityName = rawCityName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cityName.isEmpty else { continue }

                    if let townsArray = rawTowns as? [String] {
                        let towns = townsArray
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .uniqued()
                            .sorted { $0.localizedCompare($1) == .orderedAscending }

                        cities.append(City(name: cityName, towns: towns))
                    } else if let nestedDict = rawTowns as? [String: Any] {
                        // 드물지만 또 한 번 감싸진 경우 방어적으로 펼침
                        var flatTowns: [String] = []
                        for (_, v) in nestedDict {
                            if let arr = v as? [String] {
                                flatTowns.append(contentsOf: arr)
                            }
                        }
                        flatTowns = flatTowns
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        cities.append(City(name: cityName, towns: flatTowns.uniqued().sorted { $0.localizedCompare($1) == .orderedAscending }))
                    } else {
                        // 지원하지 않는 타입은 스킵
                        continue
                    }
                }

            case let array as [Any]:
                // 특수 케이스: "기장군 " : [ "기장읍", "…" ] 처럼 바로 배열인 경우
                let towns = array.compactMap { $0 as? String }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .uniqued()
                    .sorted { $0.localizedCompare($1) == .orderedAscending }
                // 배열 키명 자체를 시/군/구 이름으로 간주
                cities.append(City(name: provinceName /* 임시 이름 보정 */, towns: towns))

            default:
                // 빈 객체 {} 등은 스킵 (예: "기장군": {})
                break
            }

            // 공백/중복 제거 및 정렬
            let normalizedCities = cities
                .filter { !$0.name.isEmpty && !$0.towns.isEmpty }
                .uniqued { $0.name }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

            if !normalizedCities.isEmpty {
                provinces.append(Province(name: provinceName, cities: normalizedCities))
            }
        }

        // 시/도 정렬
        provinces.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        return provinces
    }
}

// MARK: - Helpers
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        var result: [Element] = []
        for e in self {
            if set.insert(e).inserted {
                result.append(e)
            }
        }
        return result
    }
}

extension Array {
    func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        var result: [Element] = []
        for e in self {
            let k = key(e)
            if seen.insert(k).inserted {
                result.append(e)
            }
        }
        return result
    }
}

// MARK: - ViewModel
enum RegionSource { case none, location, picker }

final class AddressPickerViewModel: ObservableObject {
    @Published var provinces: [Province] = []
    @Published var selectedProvinceIndex: Int = 0 {
        didSet { selectedCityIndex = 0; selectedTownIndex = 0 }
    }
    @Published var selectedCityIndex: Int = 0 {
        didSet { selectedTownIndex = 0 }
    }
    @Published var selectedTownIndex: Int = 0

    @Published var loadErrorMessage: String?

    var selectedProvince: Province? {
        guard provinces.indices.contains(selectedProvinceIndex) else { return nil }
        return provinces[selectedProvinceIndex]
    }
    var selectedCity: City? {
        guard let p = selectedProvince, p.cities.indices.contains(selectedCityIndex) else { return nil }
        return p.cities[selectedCityIndex]
    }
    var selectedTown: String? {
        guard let c = selectedCity, c.towns.indices.contains(selectedTownIndex) else { return nil }
        return c.towns[selectedTownIndex]
    }

    var composedAddress: String {
        // "00구/군/시 + 00동/읍/면/리" 형태 (요구사항에 맞춰 시/군/구 + 읍/면/동/리)
        let sigungu = selectedCity?.name ?? ""
        let town = selectedTown ?? ""
        return [sigungu, town].filter { !$0.isEmpty }.joined(separator: " ")
    }

    func load() {
        do {
            provinces = try AddressLoader.loadFromBundle()
            loadErrorMessage = provinces.isEmpty ? "주소 데이터를 불러오지 못했습니다." : nil
        } catch AddressLoadError.fileNotFound {
            loadErrorMessage = "3depth.json 파일을 앱 번들(Resources)에 추가했는지 확인하세요."
        } catch {
            loadErrorMessage = "주소 데이터 파싱에 실패했습니다."
        }
    }
}
