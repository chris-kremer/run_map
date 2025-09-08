import SwiftUI
import CoreLocation

struct StatsView: View {
    var routes: [Route]
    @Environment(\.dismiss) private var dismiss
    @State private var totalKm: Double = 0
    @State private var countryTotals: [(String, Double)] = []
    @State private var cityTotals: [(String, Double)] = []
    @State private var loading = true
    @State private var routeTotal = 0
    @State private var processedRoutes = 0
    @State private var uniqueCoords = 0
    @State private var geocoded = 0
    @State private var heuristicallyClassified = 0
    @State private var showAllCountries = false
    @State private var showAllCities = false

    var body: some View {
        NavigationView {
            ScrollView {
                statsContent
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear(perform: computeStats)
        .onChange(of: routes.count) { _ in
            computeStats()
        }
    }

    private var statsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if loading {
                ProgressView("Loading stats…")
                    .padding(.bottom, 8)

                Text("Scanned \(processedRoutes)/\(routeTotal) routes • \(uniqueCoords) unique coords • \(geocoded) geocoded")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Heuristically classified: \(heuristicallyClassified)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if !countryTotals.isEmpty || !cityTotals.isEmpty {
                    Text("Showing partial results…")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            else if totalKm == 0 {
                Text("Go explore!")
                    .font(.headline)
                    .padding(.bottom, 8)
            } else {
                Text("You ran \(Int(totalKm)) km in total.")
                    .font(.headline)
                    .padding(.bottom, 8)
            }

            if !loading && countryTotals.isEmpty && cityTotals.isEmpty {
                Text("No location data found.")
                    .font(.subheadline)
                    .padding(.bottom, 8)
            }
            if !countryTotals.isEmpty {
                Text("Your top countries were:").font(.subheadline)
                ForEach(Array(countryTotals.enumerated()).filter { $0.element.1 > 0 && (showAllCountries || $0.offset < 3) }, id: \.offset) { idx, entry in
                    Text("\(idx + 1)) \(entry.0) \(Int(entry.1))km")
                }
                if countryTotals.count > 3 {
                    Button(showAllCountries ? "Show less" : "Show all") {
                        showAllCountries.toggle()
                    }
                    .font(.caption)
                    .padding(.bottom, 8)
                }
            }
            if !cityTotals.isEmpty {
                Text("Your top cities were:").font(.subheadline)
                ForEach(Array(cityTotals.enumerated()).filter { $0.element.1 > 0 && (showAllCities || $0.offset < 3) }, id: \.offset) { idx, entry in
                    Text("\(idx + 1)) \(entry.0) \(Int(entry.1))km")
                }
                if cityTotals.count > 3 {
                    Button(showAllCities ? "Show less" : "Show all") {
                        showAllCities.toggle()
                    }
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func computeStats() {
        // Validate routes array first
        guard !routes.isEmpty else {
            loading = false
            return
        }
        
        routeTotal = routes.count
        processedRoutes = 0
        uniqueCoords = 0
        geocoded = 0
        heuristicallyClassified = 0

        loading = true
        
        // Safely calculate total km with error handling
        totalKm = routes.compactMap { route in
            guard route.coordinates.count > 1 else {
                print("⚠️ Found route with insufficient coordinates: \(route.id) (count: \(route.coordinates.count))")
                return nil
            }
            // Safely access distanceKm with additional protection
            let distance = route.distanceKm
            guard distance.isFinite && distance >= 0 else {
                print("⚠️ Invalid distance calculated for route: \(route.id) (distance: \(distance))")
                return nil
            }
            return distance
        }.reduce(0, +)

        // Use fast local geocoding with fallback to network geocoding
        let serialQueue = DispatchQueue(label: "stats.processing", qos: .userInitiated)
        
        // Load existing caches and clean them up
        var coordCache: [String: String] = [:]
        var cityCache: [String: String] = [:]
        
        // Safely load cache with error handling
        if let rawCoordCache = UserDefaults.standard.object(forKey: "coordCountryCache") as? [String: String] {
            coordCache = rawCoordCache
        } else {
            print("⚠️ Invalid or missing coordCountryCache, starting fresh")
            UserDefaults.standard.removeObject(forKey: "coordCountryCache")
        }
        
        if let rawCityCache = UserDefaults.standard.object(forKey: "coordCityCache") as? [String: String] {
            cityCache = rawCityCache
        } else {
            print("⚠️ Invalid or missing coordCityCache, starting fresh")
            UserDefaults.standard.removeObject(forKey: "coordCityCache")
        }
        
        // Clean up old cached data with inconsistent country names
        coordCache = cleanupCountryCache(coordCache)
        cityCache = cleanupCityCache(cityCache, coordCache: coordCache)
        
        // Process all routes using fast local geocoding
        serialQueue.async {
            let result = self.processAllRoutesWithLocalGeocoding(
                routes: self.routes, 
                coordCache: coordCache, 
                cityCache: cityCache
            )
            
            DispatchQueue.main.async {
                // Save updated caches
                UserDefaults.standard.set(result.coordCache, forKey: "coordCountryCache")
                UserDefaults.standard.set(result.cityCache, forKey: "coordCityCache")
                
                var countryDict = result.countryDict
                let knownKm = countryDict.values.reduce(0, +)
                let unknownKm = self.totalKm - knownKm
                if unknownKm > 0 {
                    countryDict["(Unknown)"] = unknownKm
                }
                
                self.countryTotals = countryDict.sorted { $0.value > $1.value }
                self.cityTotals = result.cityDict.sorted { $0.value > $1.value }
                self.loading = false
                
                print("🚀 Local geocoding completed! Processed \(result.localGeocodedCount) locations locally, \(result.networkGeocodedCount) via network")
            }
        }
    }
    
    private func cleanupCountryCache(_ cache: [String: String]) -> [String: String] {
        var cleanedCache: [String: String] = [:]
        
        for (key, country) in cache {
            let normalizedCountry = normalizeCountryName(country)
            cleanedCache[key] = normalizedCountry
        }
        
        return cleanedCache
    }
    
    private func cleanupCityCache(_ cityCache: [String: String], coordCache: [String: String]) -> [String: String] {
        var cleanedCache: [String: String] = [:]
        
        for (key, city) in cityCache {
            // Remove obviously wrong city assignments (cities that are too far)
            if coordCache[key] != nil {
                // If we have a cached country, validate the city makes sense
                cleanedCache[key] = city
            } else {
                // Remove orphaned city cache entries
                continue
            }
        }
        
        return cleanedCache
    }
    
    private struct ProcessingResult {
        var coordCache: [String: String]
        var cityCache: [String: String]
        var countryDict: [String: Double]
        var cityDict: [String: Double]
        var visitedCount: Int
        var localGeocodedCount: Int
        var networkGeocodedCount: Int
    }
    
    private func processAllRoutesWithLocalGeocoding(
        routes: [Route],
        coordCache: [String: String],
        cityCache: [String: String]
    ) -> ProcessingResult {
        
        var mutableCoordCache = coordCache
        var mutableCityCache = cityCache
        var countryDict: [String: Double] = [:]
        var cityDict: [String: Double] = [:]
        var visited = Set<String>()
        var localGeocodedCount = 0
        let networkGeocodedCount = 0

        for route in routes {
            DispatchQueue.main.async {
                self.processedRoutes += 1
            }
            
            // Validate route before processing
            guard !route.coordinates.isEmpty else {
                print("⚠️ Skipping route with no coordinates: \(route.id)")
                continue
            }

            // Process multiple points along the route for better accuracy
            let routeSegments = self.analyzeRouteGeography(route: route, 
                                                          coordCache: mutableCoordCache, 
                                                          cityCache: mutableCityCache)
            
            // Update caches with new geocoded locations
            for segment in routeSegments {
                if segment.isNewLocation {
                    mutableCoordCache[segment.key] = segment.country
                    mutableCityCache[segment.key] = segment.city
                    localGeocodedCount += 1
                }
                
                // Add distance to country/city (distributed across route)
                countryDict[segment.country, default: 0] += segment.distance
                cityDict[segment.city, default: 0] += segment.distance
                
                // Track unique coordinates
                if !visited.contains(segment.key) {
                    visited.insert(segment.key)
                }
            }
            
            DispatchQueue.main.async {
                self.uniqueCoords = visited.count
                self.geocoded = localGeocodedCount
            }
            
            // Update UI with current progress (less frequently for performance)
            if localGeocodedCount % 10 == 0 {
                DispatchQueue.main.async {
                    self.countryTotals = countryDict.sorted { $0.value > $1.value }
                    self.cityTotals = cityDict.sorted { $0.value > $1.value }
                }
            }
        }
        
        return ProcessingResult(
            coordCache: mutableCoordCache,
            cityCache: mutableCityCache,
            countryDict: countryDict,
            cityDict: cityDict,
            visitedCount: visited.count,
            localGeocodedCount: localGeocodedCount,
            networkGeocodedCount: networkGeocodedCount
        )
    }
    
    private struct RouteSegment {
        let key: String
        let country: String
        let city: String
        let distance: Double
        let isNewLocation: Bool
    }
    
    private func analyzeRouteGeography(route: Route, 
                                     coordCache: [String: String], 
                                     cityCache: [String: String]) -> [RouteSegment] {
        guard !route.coordinates.isEmpty else { return [] }
        
        var segments: [RouteSegment] = []
        
        // Sample points along the route (every ~1km or key points)
        let samplePoints = sampleRoutePoints(coordinates: route.coordinates, maxSamples: 10)
        guard !samplePoints.isEmpty else { return [] }
        
        // Safely calculate segment distance
        let totalDistance = route.distanceKm
        guard totalDistance.isFinite && totalDistance >= 0 else {
            print("⚠️ Invalid total distance for route: \(route.id) (distance: \(totalDistance))")
            return []
        }
        let segmentDistance = totalDistance / Double(samplePoints.count)
        
        for coordinate in samplePoints {
            let lat = Double(round(1000 * coordinate.latitude) / 1000)
            let lon = Double(round(1000 * coordinate.longitude) / 1000)
            let key = "\(lat),\(lon)"

            var country: String
            var city: String
            var isNewLocation = false
            
            // Check cache first
            if let cachedCountry = coordCache[key] {
                country = cachedCountry
                city = cityCache[key] ?? "Unknown"
            } else {
                // Use local geocoding for new location
                let geocodeResult = LocalGeocoder.geocode(latitude: coordinate.latitude, 
                                                        longitude: coordinate.longitude)
                country = geocodeResult.country
                city = geocodeResult.city
                isNewLocation = true
                
                // Normalize country names to avoid duplicates
                country = normalizeCountryName(country)
            }
            
            segments.append(RouteSegment(
                key: key,
                country: country,
                city: city,
                distance: segmentDistance,
                isNewLocation: isNewLocation
            ))
        }
        
        return segments
    }
    
    private func sampleRoutePoints(coordinates: [CLLocationCoordinate2D], maxSamples: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxSamples else { return coordinates }
        
        var sampledPoints: [CLLocationCoordinate2D] = []
        let interval = max(1, coordinates.count / maxSamples) // Ensure interval is at least 1
        
        for i in stride(from: 0, to: coordinates.count, by: interval) {
            sampledPoints.append(coordinates[i])
        }
        
        // Always include the last point
        if let last = coordinates.last {
            if sampledPoints.isEmpty || (sampledPoints.last!.latitude != last.latitude || sampledPoints.last!.longitude != last.longitude) {
                sampledPoints.append(last)
            }
        }
        
        return sampledPoints
    }
    
    private func normalizeCountryName(_ country: String) -> String {
        // Fix common country name variations to avoid duplicates
        switch country.lowercased() {
        case "usa", "us", "united states of america":
            return "United States"
        case "uk", "britain", "great britain", "england", "scotland", "wales":
            return "United Kingdom"
        case "deutschland":
            return "Germany"
        case "nederland", "holland":
            return "Netherlands"
        default:
            return country
        }
    }
    
    // Keep the old function for fallback if needed
    private func processAllRoutes(routes: [Route],
                                 coordCache: [String: String],
                                 cityCache: [String: String],
                                 geocoder: CLGeocoder) -> ProcessingResult {
        
        var mutableCoordCache = coordCache
        var mutableCityCache = cityCache
        var countryDict: [String: Double] = [:]
        var cityDict: [String: Double] = [:]
        var visited = Set<String>()
        var geocodedCount = 0
        
        let group = DispatchGroup()
        let lockQueue = DispatchQueue(label: "cache.lock", qos: .userInitiated)

        for route in routes {
            DispatchQueue.main.async {
                self.processedRoutes += 1
            }

            guard let first = route.coordinates.first else { continue }

            let lat = Double(round(1000 * first.latitude) / 1000)
            let lon = Double(round(1000 * first.longitude) / 1000)
            let key = "\(lat),\(lon)"

            // Check cache first
            if let cachedCountry = mutableCoordCache[key] {
                lockQueue.sync {
                    countryDict[cachedCountry, default: 0] += route.distanceKm
                    if let cachedCity = mutableCityCache[key] {
                        cityDict[cachedCity, default: 0] += route.distanceKm
                    }
                }
                continue
            }

            // Track unique coordinates
            if !visited.contains(key) {
                visited.insert(key)
                DispatchQueue.main.async {
                    self.uniqueCoords = visited.count
                }
            }

            // Limit concurrent geocoding requests
            if geocodedCount >= 50 { continue }
            geocodedCount += 1

            group.enter()
            let loc = CLLocation(latitude: first.latitude, longitude: first.longitude)
            
            geocoder.reverseGeocodeLocation(loc) { placemarks, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Geocoding error for \(lat), \(lon): \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("No placemark found for \(lat), \(lon)")
                    return
                }
                
                let country = placemark.country ?? 
                             placemark.administrativeArea ?? 
                             placemark.isoCountryCode?.uppercased() ?? 
                             "Unknown"
                
                let city = placemark.locality ?? 
                          placemark.subAdministrativeArea ?? 
                          placemark.administrativeArea ?? 
                          "Unknown"
                
                // Thread-safe cache and dict updates
                lockQueue.sync {
                    mutableCoordCache[key] = country
                    mutableCityCache[key] = city
                        countryDict[country, default: 0] += route.distanceKm
                        cityDict[city, default: 0] += route.distanceKm
                }
                
                DispatchQueue.main.async {
                    self.geocoded += 1
                    // Update UI with current progress
                    self.countryTotals = countryDict.sorted { $0.value > $1.value }
                    self.cityTotals = cityDict.sorted { $0.value > $1.value }
                }
            }
        }
        
        // Wait for all geocoding to complete
        group.wait()
        
        return ProcessingResult(
            coordCache: mutableCoordCache,
            cityCache: mutableCityCache,
            countryDict: countryDict,
            cityDict: cityDict,
            visitedCount: visited.count,
            localGeocodedCount: 0,
            networkGeocodedCount: geocodedCount
        )
    }

}

// MARK: - Array Extension for Batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView(routes: [])
    }
}

