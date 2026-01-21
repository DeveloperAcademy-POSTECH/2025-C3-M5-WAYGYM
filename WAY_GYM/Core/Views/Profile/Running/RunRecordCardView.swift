//
//  RunRecordCardView.swift
//  WAY_GYM
//
//  Created by 이주현 on 1/18/26.
//

import SwiftUI

struct RunRecordCardView: View {
    let summary: RunRecordModel
    
    private var durationSeconds: TimeInterval {
        if summary.duration > 0 { return summary.duration }
        if let end = summary.endTime { return end.timeIntervalSince(summary.startTime) }
        return 0
    }
    
    private var capturedAreaM2: Int {
        summary.capturedCellIds.count * 100
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 1️⃣ 카드 본문
            VStack(alignment: .center, spacing: 16) {
                HStack {
                    MiniMapThumbnail(
                        route: PolylineDecoder.decode(routeEncoded: summary.routeEncoded),
                        polygons: []
                    )
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding(.trailing, 16)

                    Text("\(capturedAreaM2)m²")
                        .font(.title01)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }

                HStack {
                    RunRecordInfoItem(
                        title: "소요시간",
                        content: "\(Int(durationSeconds) / 60):\(String(format: "%02d", Int(durationSeconds) % 60))"
                    )
                    Spacer()
                    RunRecordInfoItem(
                        title: "거리",
                        content: "\(String(format: "%.2f", summary.distanceM / 1000))km"
                    )
                    Spacer()
                    RunRecordInfoItem(
                        title: "거리",
                        content: "\(String(format: "%.2f", summary.distanceM / 1000))km"
                    )
                }
                .padding(.horizontal, 10)
            }
            .padding(20)

            // 2️⃣ 날짜 (카드 내용의 일부)
            Text(summary.startTime.formattedDate())
                .font(.text01)
                .foregroundColor(.text_secondary)
                .padding(20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 1)
                .stroke(Color.gang_bg_secondary_2, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 하단 info
private struct RunRecordInfoItem: View {
    let title: String
    let content: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.text01)
                .foregroundColor(.text_secondary)
            Text(content)
                .font(.title01)
                .foregroundColor(.text_primary)
        }
    }
}

// MARK: - MiniMap Thumbnail View
struct MiniMapThumbnail: View {
    let route: [CLPoint]
    let polygons: [[CLPoint]]
    let showsBackground: Bool

    init(route: [CLPoint], polygons: [[CLPoint]], showsBackground: Bool = true) {
        self.route = route
        self.polygons = polygons
        self.showsBackground = showsBackground
    }

    // 렌더링 여백
    private let paddingRatio: CGFloat = 0.12

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let allPoints = route + polygons.flatMap { $0 }
            let bounds = Bounds.from(points: allPoints)
            let projector = Projector(bounds: bounds, canvasSize: size, paddingRatio: paddingRatio)

            ZStack {
                if showsBackground {
                    MiniMapBackground()
                        .clipShape(Rectangle())
                }

                Canvas { context, _ in
                    // 1) polygon fill
                    for polygon in polygons where polygon.count >= 3 {
                        var path = Path()
                        let first = projector.toPoint(polygon[0])
                        path.move(to: first)
                        for p in polygon.dropFirst() {
                            path.addLine(to: projector.toPoint(p))
                        }
                        path.closeSubpath()

                        context.fill(path, with: .color(Color.green.opacity(0.18)))
                        context.stroke(path, with: .color(Color.green.opacity(0.35)), lineWidth: 1)
                    }

                    // 2) route polyline
                    if route.count >= 2 {
                        var path = Path()
                        path.move(to: projector.toPoint(route[0]))
                        for p in route.dropFirst() {
                            path.addLine(to: projector.toPoint(p))
                        }

                        context.stroke(path, with: .color(Color.green.opacity(0.22)), lineWidth: 8)
                        context.stroke(path, with: .color(Color.green.opacity(0.95)), lineWidth: 2.5)
                    }

                    // 3) start/end markers
                    if let start = route.first, let end = route.last {
                        let s = projector.toPoint(start)
                        let e = projector.toPoint(end)

                        drawMarker(context: &context, center: s, radius: 5, fill: Color.green.opacity(0.55))
                        drawMarker(context: &context, center: e, radius: 5, fill: Color.green.opacity(0.95))
                    }
                }

                if showsBackground {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.20),
                            Color.black.opacity(0.05),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.overlay)
                }
            }
        }
    }

    private func drawMarker(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, fill: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let circle = Path(ellipseIn: rect)
        context.fill(circle, with: .color(fill))
        context.stroke(circle, with: .color(Color.black.opacity(0.15)), lineWidth: 1)
    }
}

struct CLPoint: Hashable {
    let latitude: Double
    let longitude: Double
}

struct Bounds {
    let minLat: Double
    let minLng: Double
    let maxLat: Double
    let maxLng: Double

    static func from(points: [CLPoint]) -> Bounds {
        guard let first = points.first else {
            return Bounds(minLat: 0, minLng: 0, maxLat: 0, maxLng: 0)
        }

        var minLat = first.latitude
        var minLng = first.longitude
        var maxLat = first.latitude
        var maxLng = first.longitude

        for p in points.dropFirst() {
            minLat = Swift.min(minLat, p.latitude)
            minLng = Swift.min(minLng, p.longitude)
            maxLat = Swift.max(maxLat, p.latitude)
            maxLng = Swift.max(maxLng, p.longitude)
        }

        // Avoid zero span
        if minLat == maxLat { maxLat += 0.000001 }
        if minLng == maxLng { maxLng += 0.000001 }

        return Bounds(minLat: minLat, minLng: minLng, maxLat: maxLat, maxLng: maxLng)
    }
}

struct Projector {
    let bounds: Bounds
    let canvasSize: CGSize
    let paddingRatio: CGFloat

    private var paddedRect: CGRect {
        let padX = canvasSize.width * paddingRatio
        let padY = canvasSize.height * paddingRatio
        return CGRect(x: padX, y: padY, width: canvasSize.width - padX * 2, height: canvasSize.height - padY * 2)
    }

    func toPoint(_ p: CLPoint) -> CGPoint {
        let rect = paddedRect
        let latSpan = bounds.maxLat - bounds.minLat
        let lngSpan = bounds.maxLng - bounds.minLng

        let xNorm = (p.longitude - bounds.minLng) / lngSpan
        let yNorm = 1.0 - (p.latitude - bounds.minLat) / latSpan // invert y

        let x = rect.minX + rect.width * CGFloat(xNorm)
        let y = rect.minY + rect.height * CGFloat(yNorm)
        return CGPoint(x: x, y: y)
    }
}

struct MiniMapBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.13, blue: 0.18),
                    Color(red: 0.10, green: 0.11, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GridOverlay(spacing: 18)
                .opacity(0.14)

            DotsOverlay()
                .opacity(0.10)
        }
    }
}

struct GridOverlay: View {
    let spacing: CGFloat

    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                var path = Path()

                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }

                ctx.stroke(path, with: .color(.white), lineWidth: 1)
            }
        }
    }
}

struct DotsOverlay: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                let cols = 22
                let rows = 14

                for r in 0..<rows {
                    for c in 0..<cols {
                        let x = size.width * CGFloat(c) / CGFloat(cols - 1)
                        let y = size.height * CGFloat(r) / CGFloat(rows - 1)

                        let rect = CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white))
                    }
                }
            }
        }
    }
}

enum PolylineDecoder {
static func decode(routeEncoded: String) -> [CLPoint] {
    var coords: [CLPoint] = []
    coords.reserveCapacity(max(16, routeEncoded.count / 4))

    let bytes = Array(routeEncoded.utf8)
    var index = 0

    var lat = 0
    var lng = 0

    while index < bytes.count {
        let (dLat, next1) = decodeComponent(bytes, startIndex: index)
        index = next1
        let (dLng, next2) = decodeComponent(bytes, startIndex: index)
        index = next2

        lat += dLat
        lng += dLng

        let latitude = Double(lat) * 1e-5
        let longitude = Double(lng) * 1e-5
        coords.append(CLPoint(latitude: latitude, longitude: longitude))
    }

    return coords
}

private static func decodeComponent(_ bytes: [UInt8], startIndex: Int) -> (Int, Int) {
    var result = 0
    var shift = 0
    var index = startIndex

    while index < bytes.count {
        let b = Int(bytes[index]) - 63
        index += 1

        result |= (b & 0x1F) << shift
        shift += 5

        if b < 0x20 { break }
    }

    let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    return (delta, index)
}
}

#Preview {
    RunRecordCardView(
        summary: RunRecordModel(
            startTime: Date().addingTimeInterval(-60 * 45), // 45분 전 시작
            endTime: Date(),
            distanceM: 5120, // 5.12km
            routeEncoded: "unb{E{_ttWxBaIA{I}BqHsF{BgFfAiErFmA`I~AhH`E~FlFr@lAm@n@e@jB{@Yo[g@bNtDhJfHxE",
            capturedCellIds: Array(repeating: "cell", count: 23), // 23칸
            routeFrame: [36.06060753312461, 129.3766648880084, 36.06647704414143, 129.38291569962857]
        )
    )
    .padding()
    .background(Color.gang_bg_primary_5)
    .font(.text01)
    .foregroundColor(Color("gang_text_2"))
}
