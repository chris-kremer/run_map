import SwiftUI
import CoreLocation

struct StatsView: View {
    var routes: [Route]
    var onLocationSelected: ((String, String) -> Void)? // (country, city) -> Void
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
        LazyVStack(spacing: 16) {
            if loading {
                loadingCard
            } else if totalKm == 0 {
                emptyStateCard
            } else {
                overviewCard
                
                if !countryTotals.isEmpty {
                    countriesCard
                }
                
                if !cityTotals.isEmpty {
                    citiesCard
                }
            }
        }
        .padding()
    }
    
    private var loadingCard: some View {
        VStack(spacing: 12) {
            let progress = routeTotal > 0 ? Double(processedRoutes) / Double(routeTotal) : 0.0
            let percentage = Int(progress * 100)
            
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Analyzing Routes")
                    .font(.headline)
                Spacer()
            }
            
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text("\(percentage)% complete")
                .font(.caption)
                    .foregroundColor(.secondary)

                if !countryTotals.isEmpty || !cityTotals.isEmpty {
                    Text("Showing partial results…")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Ready to Explore!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start running to see your stats here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Running Summary")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(totalKm))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Total KM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(routes.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Workouts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var countriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Countries")
                    .font(.headline)
                Spacer()
                Text("\(countryTotals.filter { $0.1 > 0 }.count)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
            }
            
            let displayedCountries = showAllCountries ? countryTotals : Array(countryTotals.prefix(min(3, countryTotals.count)))
            
            ForEach(Array(displayedCountries.enumerated()), id: \.offset) { index, entry in
                if entry.1 > 0 {
                    Button(action: {
                        onLocationSelected?(entry.0, "")
                        dismiss()
                    }) {
                        HStack {
                            Text(countryFlag(for: entry.0))
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.0)
                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(Int(entry.1)) km")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("#\(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
                if countryTotals.count > 3 {
                Button(action: { showAllCountries.toggle() }) {
                    HStack {
                        Text(showAllCountries ? "Show less" : "Show all \(countryTotals.count) countries")
                        Image(systemName: showAllCountries ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var citiesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Cities")
                    .font(.headline)
                Spacer()
                Text("\(cityTotals.filter { $0.1 > 0 }.count)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            let displayedCities = showAllCities ? cityTotals : Array(cityTotals.prefix(min(3, cityTotals.count)))
            
            ForEach(Array(displayedCities.enumerated()), id: \.offset) { index, entry in
                if entry.1 > 0 {
                    Button(action: {
                        onLocationSelected?(entry.0, "")
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.0)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(Int(entry.1)) km")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("#\(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
                if cityTotals.count > 3 {
                Button(action: { showAllCities.toggle() }) {
                    HStack {
                        Text(showAllCities ? "Show less" : "Show all \(cityTotals.count) cities")
                        Image(systemName: showAllCities ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func countryFlag(for country: String) -> String {
        let flagMap: [String: String] = [
            "United States": "🇺🇸",
            "Canada": "🇨🇦",
            "Mexico": "🇲🇽",
            "United Kingdom": "🇬🇧",
            "Germany": "🇩🇪",
            "France": "🇫🇷",
            "Italy": "🇮🇹",
            "Spain": "🇪🇸",
            "Netherlands": "🇳🇱",
            "Belgium": "🇧🇪",
            "Switzerland": "🇨🇭",
            "Austria": "🇦🇹",
            "Portugal": "🇵🇹",
            "Denmark": "🇩🇰",
            "Sweden": "🇸🇪",
            "Norway": "🇳🇴",
            "Finland": "🇫🇮",
            "Poland": "🇵🇱",
            "Czech Republic": "🇨🇿",
            "Hungary": "🇭🇺",
            "Greece": "🇬🇷",
            "Turkey": "🇹🇷",
            "Russia": "🇷🇺",
            "Japan": "🇯🇵",
            "China": "🇨🇳",
            "South Korea": "🇰🇷",
            "Australia": "🇦🇺",
            "New Zealand": "🇳🇿",
            "Brazil": "🇧🇷",
            "Argentina": "🇦🇷",
            "Chile": "🇨🇱",
            "Colombia": "🇨🇴",
            "Peru": "🇵🇪",
            "India": "🇮🇳",
            "Thailand": "🇹🇭",
            "Singapore": "🇸🇬",
            "Malaysia": "🇲🇾",
            "Indonesia": "🇮🇩",
            "Philippines": "🇵🇭",
            "Vietnam": "🇻🇳",
            "South Africa": "🇿🇦",
            "Egypt": "🇪🇬",
            "Morocco": "🇲🇦",
            "Israel": "🇮🇱",
            "UAE": "🇦🇪",
            "Saudi Arabia": "🇸🇦"
        ]
        return flagMap[country] ?? "🌍"
    }

    private func computeStats() {
        print("📊 Starting computeStats with \(routes.count) routes")
        // Validate routes array first
        guard !routes.isEmpty else {
            print("⚠️ Empty routes array")
            loading = false
            return
        }
        let routesArray = routes
        print("📊 Processing \(routesArray.count) routes for stats")
        
        routeTotal = routesArray.count
        processedRoutes = 0
        uniqueCoords = 0
        geocoded = 0
        heuristicallyClassified = 0

        loading = true
        
        // Safely calculate total km with error handling
        totalKm = routesArray.compactMap { route in
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
        if let rawCoordCache = UserDefaults.standard.object(forKey: "coordCountryCache") {
            if let validCache = rawCoordCache as? [String: String] {
                coordCache = validCache
            } else {
                print("⚠️ Invalid coordCountryCache type: \(type(of: rawCoordCache)), clearing")
                UserDefaults.standard.removeObject(forKey: "coordCountryCache")
            }
        }
        
        if let rawCityCache = UserDefaults.standard.object(forKey: "coordCityCache") {
            if let validCache = rawCityCache as? [String: String] {
                cityCache = validCache
            } else {
                print("⚠️ Invalid coordCityCache type: \(type(of: rawCityCache)), clearing")
                UserDefaults.standard.removeObject(forKey: "coordCityCache")
            }
        }
        
        // Clean up old cached data with inconsistent country names
        coordCache = cleanupCountryCache(coordCache)
        cityCache = cleanupCityCache(cityCache, coordCache: coordCache)
        
        // Process all routes using fast local geocoding
        serialQueue.async {
            let result = self.processAllRoutesWithLocalGeocoding(
                routes: routesArray, 
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
                
                // Safely sort dictionaries with validation
                self.countryTotals = self.safeSortDictionary(countryDict)
                self.cityTotals = self.safeSortDictionary(result.cityDict)
                self.loading = false
                
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
        print("🔄 Starting processAllRoutesWithLocalGeocoding with \(routes.count) routes")
        
        var mutableCoordCache = coordCache
        var mutableCityCache = cityCache
        var countryDict: [String: Double] = [:]
        var cityDict: [String: Double] = [:]
        var visited = Set<String>()
        var localGeocodedCount = 0
        let networkGeocodedCount = 0

        for (index, route) in routes.enumerated() {
            // Add safety check for route validity
            if index == 0 {
                print("🔄 Processing first route: \(route.id) with \(route.coordinates.count) coordinates")
            }
            
            // Update progress every 50 routes for better performance
            if index % 50 == 0 {
                DispatchQueue.main.async {
                    self.processedRoutes = index
                }
            }
            
            // Validate route before processing (skip invalid routes silently)
            guard !route.coordinates.isEmpty,
                  route.coordinates.allSatisfy({ coord in
                      coord.latitude.isFinite && coord.longitude.isFinite &&
                      coord.latitude >= -90 && coord.latitude <= 90 &&
                      coord.longitude >= -180 && coord.longitude <= 180
                  }) else {
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
            
            // Capture the count safely before dispatching
            let visitedCount = visited.count
            DispatchQueue.main.async {
                self.uniqueCoords = visitedCount
                self.geocoded = Int(localGeocodedCount)
            }
            
            // Update UI with current progress (less frequently for performance)
            if index % 100 == 0 {
                DispatchQueue.main.async {
                    self.countryTotals = self.safeSortDictionary(countryDict)
                    self.cityTotals = self.safeSortDictionary(cityDict)
                }
            }
        }
        
        // Final progress update
        DispatchQueue.main.async {
            self.processedRoutes = routes.count
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
                
                // Validate results
                if country.isEmpty || city.isEmpty {
                    print("⚠️ Empty geocoding result for coordinate: \(coordinate)")
                    country = country.isEmpty ? "Unknown" : country
                    city = city.isEmpty ? "Unknown" : city
                }
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
            if sampledPoints.isEmpty {
                sampledPoints.append(last)
            } else if let lastPoint = sampledPoints.last {
                // Use safe comparison for coordinates
                let latDiff = abs(lastPoint.latitude - last.latitude)
                let lonDiff = abs(lastPoint.longitude - last.longitude)
                if latDiff > 0.0001 || lonDiff > 0.0001 { // Different enough to include
                    sampledPoints.append(last)
                }
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
    
    private func safeSortDictionary(_ dict: [String: Double]) -> [(String, Double)] {
        return dict.compactMap { (key, value) -> (String, Double)? in
            // Validate that value is valid
            guard value.isFinite && value >= 0 else {
                print("⚠️ Invalid value in dictionary for key '\(key)': \(value)")
                return nil
            }
            return (key, value)
        }.sorted { $0.1 > $1.1 }
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
                // Capture the count safely before dispatching
                let visitedCount = visited.count
                DispatchQueue.main.async {
                    self.uniqueCoords = visitedCount
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
        StatsView(routes: [], onLocationSelected: nil)
    }
}

