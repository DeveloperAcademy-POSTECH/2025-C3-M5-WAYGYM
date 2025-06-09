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
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var overlays: [MKOverlay] = []
    let viewModel = RunRecordViewModel()
    
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, interactionModes: [])
                   .overlay {
                       MapOverlay(overlays: overlays)
                   }
            .ignoresSafeArea()
            .onAppear {
                let polys = viewModel.makePolygons(from: summary.capturedAreas)
                let lines = viewModel.makePolylines(from: summary.coordinates)
                overlays = polys + lines

                let coords = summary.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }

                if coords.count >= 2 {
                    let lats = coords.map { $0.latitude }
                    let lons = coords.map { $0.longitude }

                    let minLat = lats.min() ?? 0
                    let maxLat = lats.max() ?? 0
                    let minLon = lons.min() ?? 0
                    let maxLon = lons.max() ?? 0

                    let centerLat = (minLat + maxLat) / 2
                    let centerLon = (minLon + maxLon) / 2

                    let spanLat = (maxLat - minLat) * 1.5
                    let spanLon = (maxLon - minLon) * 1.5

                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                        span: MKCoordinateSpan(
                            latitudeDelta: max(spanLat, 0.005),
                            longitudeDelta: max(spanLon, 0.005)
                        )
                    )
                }
            }
            
            VStack {
                Spacer()
                
                VStack {
                    HStack {
                        customLabel(value: "\(Int(summary.capturedArea))", title:
                                        "영역(m²)")
                        
                        Spacer()
                        
                        VStack() {
                            Text(summary.startTime.formattedYMD())
                            Text("\(summary.startTime.formattedHM()) (\(summary.startTime.koreanWeekday()))")
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
                        customLabel(value: String(Int(summary.calories)), title: "칼로리")
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
    
    struct MapOverlay: UIViewRepresentable {
        let overlays: [MKOverlay]

        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.delegate = context.coordinator
            mapView.isUserInteractionEnabled = false
            return mapView
        }

        func updateUIView(_ uiView: MKMapView, context: Context) {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlays(overlays)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator: NSObject, MKMapViewDelegate {
            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                if let polygon = overlay as? MKPolygon {
                    let renderer = MKPolygonRenderer(polygon: polygon)
                    renderer.fillColor = UIColor.green.withAlphaComponent(0.3)
                    renderer.strokeColor = UIColor.green
                    renderer.lineWidth = 2
                    return renderer
                } else if let polyline = overlay as? MKPolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = UIColor.blue
                    renderer.lineWidth = 2
                    return renderer
                }
                return MKOverlayRenderer()
            }
        }
    }
    
}

//#Preview {
//    BigSingleRunningView(summary: RunSummary)
//        .foregroundColor(Color.gang_text_2)
//        .font(.title01)
//}
