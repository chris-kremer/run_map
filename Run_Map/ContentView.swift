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

// New LocationManager that requests authorization.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Request authorization.
        locationManager.requestWhenInUseAuthorization()
    }
}

// Updated Route model now includes the workout date.
struct Route: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let date: Date
}

class RunViewModel: ObservableObject {
    @Published var routes: [Route] = []
    
    let healthManager = HealthManager()
    
    func loadRuns() {
        // Fetch running & walking workouts and add the start date.
        healthManager.fetchRunningWorkouts { workouts in
            for workout in workouts {
                self.healthManager.fetchRoute(for: workout) { locations in
                    let coordinates = locations.map { $0.coordinate }
                    DispatchQueue.main.async {
                        self.routes.append(Route(coordinates: coordinates, date: workout.startDate))
                    }
                }
            }
        }
    }
}

// Custom polyline subclass that stores the workout date.
class RoutePolyline: MKPolyline {
    var routeDate: Date?
}

struct ContentView: View {
    @StateObject private var viewModel = RunViewModel()
    @StateObject private var locationManager = LocationManager() // <-- Instantiate LocationManager.
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    // The slider value (in days). We'll use a range from 0 to 7 days.
    @State private var recentDays: Double = 2
    // Track whether to show the loading overlay.
    @State private var isLoading: Bool = true
    // Track whether the slider panel is expanded.
    @State private var sliderExpanded: Bool = false
    
    var body: some View {
        ZStack {
            // Map view that ignores safe areas.
            RouteMapView(routes: viewModel.routes, region: region, recentDays: Int(recentDays))
                .ignoresSafeArea()
            
            // Loading overlay.
            if isLoading {
                Text("Loading")
                    .font(.largeTitle)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // Conditional slider button / panel at the bottom left.
            VStack {
                Spacer()
                HStack {
                    if sliderExpanded {
                        // Expanded slider panel.
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Highlight workouts from last \(Int(recentDays)) day\(Int(recentDays) == 1 ? "" : "s")")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        sliderExpanded = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                }
                            }
                            Slider(value: $recentDays, in: 0...7, step: 1)
                        }
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .transition(.move(edge: .bottom))
                    } else {
                        // Collapsed state: show an icon.
                        Button(action: {
                            withAnimation {
                                sliderExpanded = true
                            }
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .padding()
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .transition(.move(edge: .bottom))
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.healthManager.requestAuthorization()
            // Load routes after a short delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                viewModel.loadRuns()
                // Hide loading overlay after routes are loaded.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isLoading = false
                }
            }
        }
        // Briefly show the loading overlay when slider value changes.
        .onChange(of: recentDays) { _ in
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isLoading = false
            }
        }
    }
}

struct RouteMapView: UIViewRepresentable {
    var routes: [Route]
    var region: MKCoordinateRegion
    var recentDays: Int
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        // Set the initial region only once.
        mapView.region = region
        // Enable showing the user's current location.
        mapView.showsUserLocation = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays.
        mapView.removeOverlays(mapView.overlays)
        // Add a custom polyline for each route.
        for route in routes {
            let polyline = RoutePolyline(coordinates: route.coordinates, count: route.coordinates.count)
            polyline.routeDate = route.date
            mapView.addOverlay(polyline)
        }
        // Keep the current map position.
        mapView.delegate = context.coordinator
        context.coordinator.recentDays = recentDays
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        // This value is updated in updateUIView.
        var recentDays: Int = 0
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let routePolyline = overlay as? RoutePolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: routePolyline)
            // Compute cutoff date based on recentDays.
            let cutoffDate = Date().addingTimeInterval(-Double(recentDays) * 24 * 3600)
            if let routeDate = routePolyline.routeDate, routeDate >= cutoffDate {
                renderer.strokeColor = .red
            } else {
                renderer.strokeColor = .systemBlue
            }
            renderer.lineWidth = 3
            return renderer
        }
    }
}
