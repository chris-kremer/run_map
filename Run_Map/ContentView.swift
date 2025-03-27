//
//  ContentView.swift
//  Run_Map
//
//  Created by Christian Kremer on 24.03.25.
//

import SwiftUI
import MapKit
import CoreLocation
import HealthKit

struct Route: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
}

class RunViewModel: ObservableObject {
    @Published var routes: [Route] = []
    
    let healthManager = HealthManager()
    
    func loadRuns() {
        // Call fetchRunningWorkouts without passing a predicate.
        healthManager.fetchRunningWorkouts { workouts in
            for workout in workouts {
                self.healthManager.fetchRoute(for: workout) { locations in
                    let coordinates = locations.map { $0.coordinate }
                    DispatchQueue.main.async {
                        self.routes.append(Route(coordinates: coordinates))
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = RunViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        RouteMapView(routes: viewModel.routes, region: region)
            .ignoresSafeArea() // Map extends from edge to edge
            .onAppear {
                viewModel.healthManager.requestAuthorization()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    viewModel.loadRuns()
                }
            }
    }
}

struct RouteMapView: UIViewRepresentable {
    var routes: [Route]
    var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.region = region
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        
        for route in routes {
            let polyline = MKPolyline(coordinates: route.coordinates, count: route.coordinates.count)
            mapView.addOverlay(polyline)
        }
        
        mapView.setRegion(region, animated: true)
        mapView.delegate = context.coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 3
            return renderer
        }
    }
}
