import SwiftUI
import MapKit
import CoreLocation
import HealthKit

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    private let locationManager = CLLocationManager()
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

final class Route: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let date: Date
    let workoutType: HKWorkoutActivityType
    let durationSec: Double

    lazy var averageSpeedKmH: Double = {
        guard durationSec > 0 else { return 0 }
        return distanceKm / (durationSec / 3600)
    }()
    
    /// Cached length in kilometres (computed only once).
    lazy var distanceKm: Double = {
        coordinates.adjacentPairs()
            .map { from, to in
                CLLocation(latitude: from.latitude, longitude: from.longitude)
                    .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
            }
            .reduce(0, +) / 1_000
    }()
    
    init(coordinates: [CLLocationCoordinate2D],
         date: Date,
         workoutType: HKWorkoutActivityType,
         durationSec: Double) {
        self.coordinates = coordinates
        self.date = date
        self.workoutType = workoutType
        self.durationSec = durationSec
    }
}

// MARK: - Persistable Route Data

struct PersistedRoute: Codable {
    let id: UUID
    let coordinates: [[String: Double]]
    let date: Date
    let workoutType: UInt
    let durationSec: Double
    
    init(from route: Route) {
        self.id = route.id
        self.coordinates = route.coordinates.map { ["lat": $0.latitude, "lon": $0.longitude] }
        self.date = route.date
        self.workoutType = route.workoutType.rawValue
        self.durationSec = route.durationSec
    }
    
    func toRoute() -> Route {
        let coords = coordinates.compactMap { dict -> CLLocationCoordinate2D? in
            guard let lat = dict["lat"], let lon = dict["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return Route(
            coordinates: coords,
            date: date,
            workoutType: HKWorkoutActivityType(rawValue: workoutType) ?? .other,
            durationSec: durationSec
        )
    }
}

// MARK: - Route Persistence Manager

class RouteStorage {
    private let fileManager = FileManager.default
    private let fileName = "cached_routes.json"
    
    private var fileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }
    
    func saveRoutes(_ routes: [Route]) {
        do {
            let persistedRoutes = routes.map { PersistedRoute(from: $0) }
            let data = try JSONEncoder().encode(persistedRoutes)
            try data.write(to: fileURL)
            print("✅ Saved \(routes.count) routes to cache")
        } catch {
            print("❌ Failed to save routes: \(error.localizedDescription)")
        }
    }
    
    func loadRoutes() -> [Route] {
        do {
            let data = try Data(contentsOf: fileURL)
            let persistedRoutes = try JSONDecoder().decode([PersistedRoute].self, from: data)
            let routes = persistedRoutes.compactMap { persistedRoute -> Route? in
                let route = persistedRoute.toRoute()
                // Filter out routes with no coordinates
                guard !route.coordinates.isEmpty else {
                    print("⚠️ Filtering out cached route with no coordinates: \(route.id)")
                    return nil
                }
                return route
            }
            print("✅ Loaded \(routes.count) routes from cache")
            return routes
        } catch {
            print("ℹ️ No cached routes found or failed to load: \(error.localizedDescription)")
            return []
        }
    }
    
    func getLastSyncDate() -> Date? {
        return UserDefaults.standard.object(forKey: "lastRouteSyncDate") as? Date
    }
    
    func setLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastRouteSyncDate")
    }
    
    func clearCache() {
        try? fileManager.removeItem(at: fileURL)
        UserDefaults.standard.removeObject(forKey: "lastRouteSyncDate")
        print("🗑️ Cleared route cache")
    }
}

// MARK: - ViewModel

class RunViewModel: ObservableObject {
    enum WorkoutFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case running = "Running"
        case walking = "Walking"
        
        var id: String { rawValue }
    }

    @Published var routes: [Route] = []
    @Published var hasContent: Bool = false
    @Published var selectedFilter: WorkoutFilter = .all

    // Loading progress tracking
    @Published var loadProgress: Double = 0        // 0‥1
    private var totalToLoad: Int = 0
    private var loadedCount: Int = 0

    var displayedRoutes: [Route] {
        switch selectedFilter {
        case .all: return routes
        case .running: return routes.filter { $0.workoutType == .running }
        case .walking: return routes.filter { $0.workoutType == .walking }
        }
    }

    var totalDistanceKm: Double {
        displayedRoutes.map(\.distanceKm).reduce(0, +)
    }

    let healthManager = HealthKitManager()
    let routeStorage = RouteStorage()
    
    func loadRuns() {
        // First, load cached routes immediately for instant UI
        let cachedRoutes = routeStorage.loadRoutes()
        if !cachedRoutes.isEmpty {
            DispatchQueue.main.async {
                self.routes = cachedRoutes
                self.hasContent = true
                self.loadProgress = 1.0
            }
        }
        
        // Then fetch new routes in background
        loadNewRuns()
    }
    
    func loadAllRunsFromScratch() {
        // Clear existing routes and cache
        DispatchQueue.main.async {
            self.routes.removeAll()
            self.hasContent = false
        }
        routeStorage.clearCache()
        
        healthManager.fetchRunningWorkouts { workouts in
            DispatchQueue.main.async {
                self.totalToLoad = workouts.count
                self.loadedCount = 0
                self.loadProgress = workouts.isEmpty ? 1 : 0
            }
            
            var newRoutes: [Route] = []
            let group = DispatchGroup()
            
            for workout in workouts {
                group.enter()
                self.healthManager.fetchRoute(for: workout) { locations in
                    let coordinates = locations.map { $0.coordinate }
                    
                    // Only process workouts that have GPS data
                    guard !coordinates.isEmpty else {
                        print("⚠️ Skipping workout with no GPS data: \(workout.startDate)")
                        group.leave()
                        return
                    }
                    
                    let segments = self.filterRoute(coordinates)
                    
                    for segment in segments {
                        // Only create routes with meaningful coordinate data
                        guard segment.count > 1 else { continue }
                        
                        let route = Route(coordinates: segment,
                                        date: workout.startDate,
                                        workoutType: workout.workoutActivityType,
                                        durationSec: workout.duration)
                        newRoutes.append(route)
                    }
                    
                    DispatchQueue.main.async {
                        self.loadedCount += 1
                        if self.totalToLoad > 0 {
                            self.loadProgress = Double(self.loadedCount) / Double(self.totalToLoad)
                        }
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.routes = newRoutes.sorted { $0.date > $1.date }
                self.hasContent = !self.routes.isEmpty
                self.routeStorage.saveRoutes(self.routes)
                self.routeStorage.setLastSyncDate(Date())
            }
        }
    }
    
    func loadNewRuns() {
        // Use either the latest cached route date or last sync date
        let lastSyncDate = routeStorage.getLastSyncDate()
        let latestRouteDate = routes.map(\.date).max()
        
        let sinceDate = [lastSyncDate, latestRouteDate].compactMap { $0 }.max() ?? Date.distantPast
        
        healthManager.fetchRunningWorkouts { workouts in
            let newWorkouts = workouts.filter { $0.startDate > sinceDate }
            
            guard !newWorkouts.isEmpty else {
                DispatchQueue.main.async {
                    self.loadProgress = 1.0
                }
                return
            }
            
            DispatchQueue.main.async {
                self.totalToLoad = newWorkouts.count
                self.loadedCount = 0
                self.loadProgress = 0
            }
            
            var newRoutes: [Route] = []
            let group = DispatchGroup()
            
            for workout in newWorkouts {
                group.enter()
                self.healthManager.fetchRoute(for: workout) { locations in
                    let coordinates = locations.map { $0.coordinate }
                    
                    // Only process workouts that have GPS data
                    guard !coordinates.isEmpty else {
                        print("⚠️ Skipping workout with no GPS data: \(workout.startDate)")
                        group.leave()
                        return
                    }
                    
                    let segments = self.filterRoute(coordinates)
                    
                    for segment in segments {
                        // Only create routes with meaningful coordinate data
                        guard segment.count > 1 else { continue }
                        
                        let route = Route(coordinates: segment,
                                        date: workout.startDate,
                                        workoutType: workout.workoutActivityType,
                                        durationSec: workout.duration)
                        newRoutes.append(route)
                    }
                    
                    DispatchQueue.main.async {
                        self.loadedCount += 1
                        if self.totalToLoad > 0 {
                            self.loadProgress = Double(self.loadedCount) / Double(self.totalToLoad)
                        }
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if !newRoutes.isEmpty {
                    self.routes.append(contentsOf: newRoutes)
                    self.routes.sort { $0.date > $1.date }
                    self.hasContent = !self.routes.isEmpty
                    
                    // Save updated routes to cache
                    self.routeStorage.saveRoutes(self.routes)
                }
                self.routeStorage.setLastSyncDate(Date())
                self.loadProgress = 1.0
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

private extension Array {
    func adjacentPairs() -> [(Element, Element)] {
        guard count > 1 else { return [] }
        return (0..<(count-1)).map { (self[$0], self[$0+1]) }
    }
}

// MARK: - RoutePolyline

class RoutePolyline: MKPolyline {
    var routeID: UUID?
    var routeDate: Date?
    var workoutType: HKWorkoutActivityType?
    var isHighlighted: Bool = false
    var averageSpeed: Double?
}

private extension RoutePolyline {
    /// Convenience factory because `MKPolyline(coordinates:count:)`
    /// is a *convenience* initializer that isn’t inherited by subclasses.
    static func fromCoordinates(_ coords: [CLLocationCoordinate2D]) -> RoutePolyline {
        // MKPolyline (and subclasses) expose an initializer that takes an *array* directly.
        return RoutePolyline(coordinates: coords, count: coords.count)
    }
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

    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("mapType") private var mapTypeRawValue: Int = Int(MKMapType.standard.rawValue)

    private var mapType: MKMapType {
        get { MKMapType(rawValue: UInt(mapTypeRawValue)) ?? .standard }
        set { mapTypeRawValue = Int(newValue.rawValue) }
    }

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var isLoading = true
    @State private var highlightedRouteIDs: Set<UUID> = []
    @State private var showLatestDayLabel = false
    @State private var showUserLocation = true
    @State private var showNoWorkouts = false

    // Tracking state variables
    @State private var isTracking = false
    @State private var liveCoordinates: [CLLocationCoordinate2D] = []
    @State private var trackingTimer: Timer?
    @State private var showControls = false
    @State private var showStats = false
    // Speed color toggle state
    @State private var colorBySpeed = false

    // Stats banner state
    @AppStorage("lastRunCount") private var lastRunCount = 0
    @AppStorage("lastDistanceKm") private var lastDistanceKm: Double = 0
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @State private var summaryMessage: String?
    @State private var showSummaryAlert = false
    @State private var hasShownSummary = false

    private func circleButton(icon: String, bg: Color = .blue) -> some View {
        Image(systemName: icon)
            .foregroundColor(.white)
            .padding()
            .background(bg)
            .clipShape(Circle())
    }


    var body: some View {
        ZStack {
            RouteMapView(routes: viewModel.displayedRoutes,
                         region: region,
                         highlightedRouteIDs: highlightedRouteIDs,
                         showUserLocation: showUserLocation,
                         liveCoordinates: liveCoordinates,
                         mapType: mapType,
                         colorBySpeed: colorBySpeed)
                .ignoresSafeArea()
            
            VStack {
                // Demo workout label
                if viewModel.routes.contains(where: { $0.date == Date.distantPast }) {
                    Text("Showing Demo Workout")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
                if showLatestDayLabel {
                    Text("Latest Day")
                        .font(.headline).bold()
                        .padding(12)
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()

                HStack {
                    Text("\(viewModel.displayedRoutes.count) workouts • " +
                         String(format: "%.1f km", viewModel.totalDistanceKm))
                        .font(.footnote).bold()
                        .padding(8)
                        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            if isLoading {
                Text("Loading \(Int(viewModel.loadProgress * 100))%")
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    if showControls {
                        // Latest‑workout button
                        circleButton(icon: "flame.fill")
                            .onTapGesture {
                                if let latest = viewModel.routes.sorted(by: { $0.date > $1.date }).first {
                                    let calendar = Calendar.current
                                    
                                    // Find all routes from the same day
                                    let routesFromLatestDay = viewModel.routes.filter { route in
                                        calendar.isDate(route.date, inSameDayAs: latest.date)
                                    }
                                    
                                    highlightedRouteIDs = Set(routesFromLatestDay.map { $0.id })
                                    
                                    // Create region that encompasses all routes from that day
                                    let allCoordinates = routesFromLatestDay.flatMap { $0.coordinates }
                                    region = coordinateRegion(for: allCoordinates)
                                    
                                    showLatestDayLabel = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        showLatestDayLabel = false
                                    }
                                }
                            }
                            .onLongPressGesture { highlightedRouteIDs.removeAll() }

                        // Tracking button
                        circleButton(icon: isTracking ? "pause.circle" : "dot.circle",
                                     bg: isTracking ? .red : .blue)
                            .onTapGesture { toggleTracking() }

                        // Update‑from‑HealthKit button
                        circleButton(icon: "arrow.clockwise")
                            .onTapGesture {
                                isLoading = true
                                viewModel.loadNewRuns()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { isLoading = false }
                            }

                        // Re‑center to current location
                        circleButton(icon: "location.fill")
                            .onTapGesture {
                                if let loc = locationManager.currentLocation {
                                    region = MKCoordinateRegion(
                                        center: loc.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                                }
                            }
                            .onLongPressGesture { showUserLocation = false }

                        // Map style toggle button
                        circleButton(icon: mapType == .standard ? "globe" : "map")
                            .onTapGesture {
                                mapTypeRawValue = Int(
                                    (mapType == .standard ? MKMapType.satellite : MKMapType.standard).rawValue
                                )
                            }

                        // Speed color toggle button
                        circleButton(icon: "speedometer")
                            .onTapGesture {
                                colorBySpeed.toggle()
                            }

                        // Stats button
                        circleButton(icon: "chart.bar")
                            .onTapGesture {
                                showStats = true
                            }

                    }

                    // Main FAB that toggles the stack
                    circleButton(icon: showControls ? "xmark" : "plus")
                        .rotationEffect(.degrees(showControls ? 45 : 0))
                        .onTapGesture {
                            withAnimation { showControls.toggle() }
                        }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onAppear {
            viewModel.healthManager.requestAuthorization { _ in
                viewModel.loadRuns()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let latest = viewModel.routes.sorted(by: { $0.date > $1.date }).first {
                        let calendar = Calendar.current
                        let routesFromLatestDay = viewModel.routes.filter { route in
                            calendar.isDate(route.date, inSameDayAs: latest.date)
                        }
                        highlightedRouteIDs = Set(routesFromLatestDay.map { $0.id })
                        let allCoordinates = routesFromLatestDay.flatMap { $0.coordinates }
                        region = coordinateRegion(for: allCoordinates)
                    }
                    isLoading = false
                }
            }
        }
        .onReceive(viewModel.$loadProgress) { progress in
            if progress >= 1 {
                // After all HealthKit queries finish decide whether to show the empty state
                showNoWorkouts = viewModel.routes.isEmpty
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
                if !hasShownSummary {
                    let newRuns = viewModel.routes.count - lastRunCount
                    let newDistance = viewModel.totalDistanceKm - lastDistanceKm
                    if hasLaunchedBefore {
                        if newRuns == 0 && newDistance == 0 {
                            summaryMessage = "Go explore!"
                        } else {
                            summaryMessage = "You added \(newRuns) runs for " +
                                String(format: "%.1f", newDistance) +
                                " km since your last visit. Great job!"
                        }
                        showSummaryAlert = true
                    }
                    lastRunCount = viewModel.routes.count
                    lastDistanceKm = viewModel.totalDistanceKm
                    hasShownSummary = true
                    hasLaunchedBefore = true
                }
            } else {
                isLoading = true
            }
        }
    // end ZStack
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenTutorial },
            set: { _ in })) {
            OnboardingView {
                hasSeenTutorial = true
            }
        }
        .fullScreenCover(isPresented: $showNoWorkouts) {
            NoWorkoutsView {
                loadDemoWorkouts()
                showNoWorkouts = false
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView(routes: viewModel.displayedRoutes)
        }
        .alert(summaryMessage ?? "", isPresented: $showSummaryAlert) {
            Button("OK", role: .cancel) { }
        }
    }   // ← closes the `var body: some View` property

    private func loadDemoWorkouts() {
        // To add additional demo workouts, drop more .gpx files into the app bundle
        // and list their base names in the `demoFiles` array below.
        let demoFiles = ["Outdoor Walk-Route-20240509_143723", "Outdoor Walk-Route-20241211_185505", "Outdoor Walk-Route-20241208_145435", "Outdoor Walk-Route-20241201_182250", "Outdoor Walk-Route-20241210_181825"]   // add more GPX names if desired
        for name in demoFiles {
            let coords = loadCoordinatesFromGPX(named: name)
            if !coords.isEmpty {
                viewModel.routes.append(
                    Route(coordinates: coords,
                          date: Date.distantPast,
                          workoutType: .walking,
                          durationSec: 0)
                )
            }
        }
        viewModel.hasContent = !viewModel.routes.isEmpty
    }

    private func toggleTracking() {
        if isTracking {
            trackingTimer?.invalidate()
            trackingTimer = nil
            isTracking = false
            if liveCoordinates.count > 1 {
                let est = Double(max(liveCoordinates.count - 1, 1)) * 5
                viewModel.routes.append(
                    Route(coordinates: liveCoordinates,
                          date: Date(),
                          workoutType: .other,
                          durationSec: est)
                )
            }
            liveCoordinates.removeAll()
        } else {
            isTracking = true
            liveCoordinates.removeAll()
            if let loc = locationManager.currentLocation?.coordinate {
                liveCoordinates.append(loc)
            }
            trackingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                if let loc = locationManager.currentLocation?.coordinate {
                    liveCoordinates.append(loc)
                }
            }
        }
    }


}

// MARK: - RouteMapView

struct RouteMapView: UIViewRepresentable {
    var routes: [Route]
    var region: MKCoordinateRegion
    var highlightedRouteIDs: Set<UUID>
    var showUserLocation: Bool
    var liveCoordinates: [CLLocationCoordinate2D]
    var mapType: MKMapType
    var colorBySpeed: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.region = region
        mapView.showsUserLocation = showUserLocation
        mapView.mapType = mapType
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Removed automatic recentering to prevent constant snapping back to Berlin.

        if mapView.showsUserLocation != showUserLocation {
            mapView.showsUserLocation = showUserLocation
        }

        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Remove existing live overlays (those without routeID)
        let liveExisting = mapView.overlays.compactMap { $0 as? MKPolyline }
            .filter { ($0 as? RoutePolyline)?.routeID == nil }
        mapView.removeOverlays(liveExisting)

        // Clean up any existing "Start" annotation
        mapView.annotations
            .filter { $0.title == "Start" }
            .forEach(mapView.removeAnnotation)

        if liveCoordinates.count > 1 {
            let live = RoutePolyline.fromCoordinates(liveCoordinates)
            mapView.addOverlay(live)

            // Drop a pin at the start
            if let start = liveCoordinates.first {
                let pin = MKPointAnnotation()
                pin.coordinate = start
                pin.title = "Start"
                mapView.addAnnotation(pin)
            }
        }

        let existing = mapView.overlays.compactMap { $0 as? RoutePolyline }
        let existingIDs = Set(existing.compactMap(\.routeID))
        let desiredIDs = Set(routes.map(\.id))

        // Remove unneeded
        let toRemove = existing.filter {
            guard let id = $0.routeID else { return false }
            return !desiredIDs.contains(id)
        }
        if !toRemove.isEmpty { mapView.removeOverlays(toRemove) }

        // Add missing
        var toAdd: [MKOverlay] = []
        for route in routes where !existingIDs.contains(route.id) {
            let pl = RoutePolyline.fromCoordinates(route.coordinates)
            pl.routeID = route.id
            pl.routeDate = route.date
            pl.workoutType = route.workoutType
            pl.isHighlighted = highlightedRouteIDs.contains(route.id)
            pl.averageSpeed = route.averageSpeedKmH
            toAdd.append(pl)
        }
        if !toAdd.isEmpty { mapView.addOverlays(toAdd) }

        // Update highlighting
        for pl in mapView.overlays.compactMap({ $0 as? RoutePolyline }) {
            let shouldHighlight = pl.routeID.map { highlightedRouteIDs.contains($0) } ?? false
            if pl.isHighlighted != shouldHighlight {
                pl.isHighlighted = shouldHighlight
                if let r = mapView.renderer(for: pl) as? MKPolylineRenderer {
                    r.strokeColor = shouldHighlight ? .orange :
                        (pl.workoutType == .running ? .systemRed :
                         pl.workoutType == .walking ? .systemBlue : .systemGreen)
                    r.setNeedsDisplay()
                }
            }
        }
    }

    // Create the coordinator that acts as MKMapViewDelegate
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: RouteMapView
        init(_ parent: RouteMapView) { self.parent = parent }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? RoutePolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            let renderer = MKPolylineRenderer(polyline: polyline)
            if polyline.isHighlighted {
                renderer.strokeColor = .orange
            } else if parent.colorBySpeed, let v = polyline.averageSpeed {
                renderer.strokeColor = {
                    switch v {
                    case ..<6:  .systemBlue
                    case ..<9:  .systemGreen
                    case ..<12: .systemOrange
                    default:    .systemRed
                    }
                }()
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
            renderer.lineWidth = 4
            return renderer
        }
    }
}


struct RouteListView: View {
    var routes: [Route]
    var select: (Route) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(routes.sorted(by: { $0.date > $1.date })) { route in
                    Button {
                        select(route)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(route.date, style: .date)
                            Text(String(format: "%.2f km", route.distanceKm))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { }
                }
            }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    var dismiss: () -> Void

    var body: some View {
        TabView {
            VStack(spacing: 24) {
                Image(systemName: "map")
                    .resizable().scaledToFit().frame(height: 120)
                Text("See all your runs and walks on a beautiful map.")
                    .font(.title3).multilineTextAlignment(.center)
            }
            .padding()

            VStack(spacing: 24) {
                Image(systemName: "record.circle")
                    .resizable().scaledToFit().frame(height: 120)
                Text("Record a live route with the • button.\nWe’ll plot it in real‑time.")
                    .font(.title3).multilineTextAlignment(.center)
            }
            .padding()

            VStack(spacing: 24) {
                Image(systemName: "flame.fill")
                    .resizable().scaledToFit().frame(height: 120)
                Text("Tap the 🔥 to jump to your latest day's workouts.\nLong‑press to clear the highlight.")
                    .font(.title3).multilineTextAlignment(.center)
            }
            .padding()

            VStack(spacing: 24) {
                Image(systemName: "plus.circle")
                    .resizable().scaledToFit().frame(height: 120)
                Text("All controls are tucked under the + button.\nTap to expand, tap × to hide.")
                    .font(.title3).multilineTextAlignment(.center)

                Button("Get Started") {
                    dismiss()
                }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(Color.blue).foregroundColor(.white)
                .clipShape(Capsule())
            }
            .padding()
        }
        .tabViewStyle(PageTabViewStyle())
    }
}

// MARK: - No Workouts View
struct NoWorkoutsView: View {
    var loadDemoAndDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "figure.walk.motion")
                .resizable().scaledToFit().frame(height: 120)
                .foregroundColor(.blue)

            Text("No workouts found")
                .font(.title).bold()

            Text("Connect to Health and record a run or tap below to load a couple of demo workouts to see the app in action.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Load Demo Workouts") {
                loadDemoAndDismiss()
            }
            .font(.headline)
            .padding(.horizontal, 32).padding(.vertical, 12)
            .background(Color.blue).foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding()
    }
}

// MARK: - GPX Parsing

import Foundation

func loadCoordinatesFromGPX(named fileName: String) -> [CLLocationCoordinate2D] {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "gpx"),
          let data = try? Data(contentsOf: url) else {
        return []
    }
    let xml = XMLParser(data: data)

    let delegate = GPXParserDelegate()
    xml.delegate = delegate
    xml.parse()
    return delegate.coordinates
}

private class GPXParserDelegate: NSObject, XMLParserDelegate {
    var coordinates: [CLLocationCoordinate2D] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if elementName == "trkpt",
           let latStr = attributeDict["lat"],
           let lonStr = attributeDict["lon"],
           let lat = Double(latStr),
           let lon = Double(lonStr) {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }
}
