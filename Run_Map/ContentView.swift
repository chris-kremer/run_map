import SwiftUI
import MapKit
import CoreLocation
import HealthKit

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.currentLocation = location
            }
        }
    }
}

// MARK: - Route Model

struct Route: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let date: Date
    let workoutType: HKWorkoutActivityType
}

// MARK: - ViewModel

class RunViewModel: ObservableObject {
    @Published var routes: [Route] = []
    let healthManager = HealthManager()
    
    func loadRuns() {
        healthManager.fetchRunningWorkouts { workouts in
            for workout in workouts {
                self.healthManager.fetchRoute(for: workout) { locations in
                    let coordinates = locations.map { $0.coordinate }
                    let segments = self.filterRoute(coordinates)
                    DispatchQueue.main.async {
                        for segment in segments {
                            self.routes.append(Route(coordinates: segment,
                                                     date: workout.startDate,
                                                     workoutType: workout.workoutActivityType))
                        }
                    }
                }
            }
        }
    }
    
    func loadNewRuns() {
        guard let latest = routes.map(\.date).max() else {
            loadRuns()
            return
        }
        
        healthManager.fetchRunningWorkouts { workouts in
            let newWorkouts = workouts.filter { $0.startDate > latest }
            for workout in newWorkouts {
                self.healthManager.fetchRoute(for: workout) { locations in
                    let coordinates = locations.map { $0.coordinate }
                    let segments = self.filterRoute(coordinates)
                    DispatchQueue.main.async {
                        for segment in segments {
                            self.routes.append(Route(coordinates: segment,
                                                     date: workout.startDate,
                                                     workoutType: workout.workoutActivityType))
                        }
                    }
                }
            }
        }
    }
    
    func filterRoute(_ coordinates: [CLLocationCoordinate2D], maxDistance: CLLocationDistance = 20) -> [[CLLocationCoordinate2D]] {
        guard coordinates.count > 1 else { return [coordinates] }
        var segments: [[CLLocationCoordinate2D]] = []
        var currentSegment = [coordinates[0]]
        
        for i in 1..<coordinates.count {
            let prev = CLLocation(latitude: coordinates[i - 1].latitude,
                                  longitude: coordinates[i - 1].longitude)
            let curr = CLLocation(latitude: coordinates[i].latitude,
                                  longitude: coordinates[i].longitude)
            if prev.distance(from: curr) <= maxDistance {
                currentSegment.append(coordinates[i])
            } else {
                if currentSegment.count > 1 {
                    segments.append(currentSegment)
                }
                currentSegment = [coordinates[i]]
            }
        }
        if currentSegment.count > 1 {
            segments.append(currentSegment)
        }
        return segments
    }
}

// MARK: - RoutePolyline

class RoutePolyline: MKPolyline {
    var routeID: UUID?
    var routeDate: Date?
    var workoutType: HKWorkoutActivityType?
    var isHighlighted: Bool = false
}

// MARK: - Map Region Computation

/// Computes an MKCoordinateRegion that fits all the given coordinates
func coordinateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
    guard !coordinates.isEmpty else {
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
                                  span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    }
    
    let latitudes = coordinates.map { $0.latitude }
    let longitudes = coordinates.map { $0.longitude }
    
    let minLat = latitudes.min()!
    let maxLat = latitudes.max()!
    let minLon = longitudes.min()!
    let maxLon = longitudes.max()!
    
    let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                        longitude: (minLon + maxLon) / 2)
    let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.3,
                                longitudeDelta: (maxLon - minLon) * 1.3)
    
    return MKCoordinateRegion(center: center, span: span)
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var viewModel = RunViewModel()
    @StateObject private var locationManager = LocationManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var isLoading = true
    @State private var highlightedRouteID: UUID?
    
    var body: some View {
        ZStack {
            RouteMapView(routes: viewModel.routes, region: region, highlightedRouteID: highlightedRouteID)
                .ignoresSafeArea()
            
            if isLoading {
                Text("Loading...")
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    // Find Last Workout Button: highlights the last route and centers map on the entire route.
                    Button {
                        if let latest = viewModel.routes.sorted(by: { $0.date > $1.date }).first {
                            highlightedRouteID = latest.id
                            // Center the map on the entire route.
                            let routeRegion = coordinateRegion(for: latest.coordinates)
                            region = routeRegion
                        }
                    } label: {
                        Image(systemName: "flame.fill")
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    
                    // Update Button
                    Button {
                        isLoading = true
                        viewModel.loadNewRuns()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isLoading = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    
                    // Location Button
                    Button {
                        if let loc = locationManager.currentLocation {
                            region = MKCoordinateRegion(
                                center: loc.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onAppear {
            viewModel.healthManager.requestAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                viewModel.loadRuns()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let latest = viewModel.routes.sorted(by: { $0.date > $1.date }).first {
                        highlightedRouteID = latest.id
                        region = coordinateRegion(for: latest.coordinates)
                    }
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - RouteMapView

struct RouteMapView: UIViewRepresentable {
    var routes: [Route]
    var region: MKCoordinateRegion
    var highlightedRouteID: UUID?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.region = region
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.removeOverlays(mapView.overlays)
        
        for route in routes {
            let polyline = RoutePolyline(coordinates: route.coordinates, count: route.coordinates.count)
            polyline.routeID = route.id
            polyline.routeDate = route.date
            polyline.workoutType = route.workoutType
            // Mark this polyline as highlighted if its ID matches.
            polyline.isHighlighted = (route.id == highlightedRouteID)
            mapView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? RoutePolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            let renderer = MKPolylineRenderer(polyline: polyline)
            // If this polyline is marked as highlighted, render it in orange.
            if polyline.isHighlighted {
                renderer.strokeColor = .orange
            } else {
                switch polyline.workoutType {
                case .running:
                    renderer.strokeColor = .systemRed
                case .walking:
                    renderer.strokeColor = .systemBlue
                default:
                    renderer.strokeColor = .systemGreen
                }
            }
            renderer.lineWidth = 3
            return renderer
        }
    }
}
