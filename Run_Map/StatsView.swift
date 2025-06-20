import SwiftUI
import CoreLocation

struct StatsView: View {
    var routes: [Route]
    @Environment(\.dismiss) private var dismiss
    @State private var totalKm: Double = 0
    @State private var countryTotals: [(String, Double)] = []
    @State private var cityTotals: [(String, Double)] = []
    @State private var loading = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You ran \(Int(totalKm))km in total.")
                        .font(.headline)
                        .padding(.bottom, 8)
                    if !countryTotals.isEmpty {
                        Text("Your top countries were:").font(.subheadline)
                        ForEach(Array(countryTotals.prefix(3).enumerated()), id: \.offset) { idx, entry in
                            Text("\(idx + 1)) \(entry.element.0) \(Int(entry.element.1))km")
                        }
                        .padding(.bottom, 8)
                    }
                    if !cityTotals.isEmpty {
                        Text("Your top cities were:").font(.subheadline)
                        ForEach(Array(cityTotals.prefix(3).enumerated()), id: \.offset) { idx, entry in
                            Text("\(idx + 1)) \(entry.element.0) \(Int(entry.element.1))km")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear(perform: computeStats)
    }

    private func computeStats() {
        totalKm = routes.map(\.distanceKm).reduce(0, +)
        let geocoder = CLGeocoder()
        var countryDict: [String: Double] = [:]
        var cityDict: [String: Double] = [:]
        let group = DispatchGroup()

        for route in routes {
            guard let first = route.coordinates.first else { continue }
            group.enter()
            let location = CLLocation(latitude: first.latitude, longitude: first.longitude)
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let placemark = placemarks?.first {
                    if let country = placemark.country {
                        countryDict[country, default: 0] += route.distanceKm
                    }
                    if let city = placemark.locality {
                        cityDict[city, default: 0] += route.distanceKm
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            countryTotals = countryDict.sorted { $0.value > $1.value }
            cityTotals = cityDict.sorted { $0.value > $1.value }
            loading = false
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView(routes: [])
    }
}
