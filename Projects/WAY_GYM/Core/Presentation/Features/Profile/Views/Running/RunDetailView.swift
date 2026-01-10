//
//  BigSingleRunningView.swift
//  WAY_GYM
//
//  Created by 이주현 on 6/4/25.
//

import SwiftUI
import MapKit

struct RunDetailView: View {
    @StateObject var viewModel: RunDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            MapOverlay(overlays: viewModel.overlays, region: viewModel.region)
                    .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack {
                    HStack {
                        customLabel(value: viewModel.areaText, title:
                                        "영역(m²)")
                    
                        Spacer()
                        
                        VStack {
                            Text(viewModel.dateText)
                            Text(viewModel.timeWeekdayText)
                        }
                        .font(.text01)
                        .padding(.trailing, 16)
                    }
                    
                    Spacer()
                        .frame(height: 24)
                    
                    HStack {
                        customLabel(value: viewModel.durationText, title: "소요시간")
                        Spacer()
                        customLabel(value: viewModel.distanceText, title: "거리(km)")
                        Spacer()
                        customLabel(value: viewModel.caloriesText, title: "칼로리")
                    }
                }
                .multilineTextAlignment(.center)
                .padding(20)
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
        let region: MKCoordinateRegion

        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.delegate = context.coordinator
            mapView.isUserInteractionEnabled = true
            mapView.setRegion(region, animated: false)
            return mapView
        }

        func updateUIView(_ uiView: MKMapView, context: Context) {
            uiView.setRegion(region, animated: false)
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
                    renderer.fillColor = UIColor.gang_area
                    return renderer
                } else if let polyline = overlay as? MKPolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = UIColor.successColor
                    renderer.lineWidth = 3
                    return renderer
                }
                return MKOverlayRenderer()
            }
        }
    }
    
}
