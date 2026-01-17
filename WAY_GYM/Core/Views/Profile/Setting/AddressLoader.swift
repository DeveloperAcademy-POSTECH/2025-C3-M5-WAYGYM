//
//  AddressLoader.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/15/26.
//
import Foundation
import CoreLocation

struct SidoNode: Codable, Hashable {
    let sido: String
    let sigungu: [SigunguNode]
}

struct SigunguNode: Codable, Hashable {
    let name: String
    let dong: [String]
}

enum AddressLoader {
    static func load3DepthJSON(named fileName: String = "3depth") throws -> [SidoNode] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw NSError(domain: "AddressLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "3depth.json not found in bundle"])
        }
        let data = try Data(contentsOf: url)
        // return try JSONDecoder().decode([SidoNode].self, from: data)
        
        // The file structure is like:
        // { "서울특별시": { "종로구": ["신교동", ...], "": {} }, "부산광역시": { ... } }
        // We use JSONSerialization to be tolerant of odd keys (e.g., empty string, leading spaces).
        let rawObj = try JSONSerialization.jsonObject(with: data, options: [])

        guard let raw = rawObj as? [String: Any] else {
            throw NSError(domain: "AddressLoader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid 3depth.json root structure"])
        }

        let locale = Locale(identifier: "ko_KR")

        let sidoNodes: [SidoNode] = raw.compactMap { (rawSido, rawSigunguAny) in
            let sido = trim(rawSido)
            guard !sido.isEmpty else { return nil }

            guard let rawSigunguDict = rawSigunguAny as? [String: Any] else {
                return nil
            }

            var sigunguNodes: [SigunguNode] = []
            sigunguNodes.reserveCapacity(rawSigunguDict.count)

            for (rawSigungu, rawDongAny) in rawSigunguDict {
                let sigungu = trim(rawSigungu)
                guard !sigungu.isEmpty else {
                    // ignore "": {} / "": [] etc.
                    continue
                }

                // Most entries are [String], but some may be {} or other invalid values.
                guard let rawDongArray = rawDongAny as? [Any] else {
                    continue
                }

                let dongs = rawDongArray.compactMap { $0 as? String }.map(trim).filter { !$0.isEmpty }.sorted { $0.compare($1, locale: locale) == .orderedAscending }
                sigunguNodes.append(SigunguNode(name: sigungu, dong: dongs))
            }

            sigunguNodes.sort { $0.name.compare($1.name, locale: locale) == .orderedAscending }
            return SidoNode(sido: sido, sigungu: sigunguNodes)
        }
        .sorted { $0.sido.compare($1.sido, locale: locale) == .orderedAscending }

        return sidoNodes
    }
    
    private static func trim(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class LocationAddressService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestOneShotLocation() async throws -> CLLocation {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        continuation?.resume(returning: loc)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func reverseGeocode(_ location: CLLocation) async throws -> (sido: String, sigungu: String, dong: String) {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR"))
        guard let p = placemarks.first else {
            throw NSError(domain: "Geocode", code: 0, userInfo: [NSLocalizedDescriptionKey: "No placemark"])
        }

        // iOS에서 보통 administrativeArea=시/도, locality=시/군/구, subLocality=동/읍/면 쪽으로 들어옴 (케이스별 보정 필요)
        let sido = p.administrativeArea ?? ""
        let sigungu = p.locality ?? p.subAdministrativeArea ?? ""
        let dong = p.subLocality ?? p.thoroughfare ?? ""

        if sido.isEmpty || sigungu.isEmpty || dong.isEmpty {
            throw NSError(domain: "Geocode", code: 1, userInfo: [NSLocalizedDescriptionKey: "Address components missing"])
        }
        return (sido, sigungu, dong)
    }
}
