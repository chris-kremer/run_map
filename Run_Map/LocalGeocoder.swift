import Foundation
import CoreLocation

// MARK: - Local Geocoding System

struct LocalGeocoder {
    
    // MARK: - Country Boundaries Database
    
    /// Lightweight country boundaries using bounding boxes and major city coordinates
    /// This provides fast, offline geocoding for most common locations
    private static let countryBoundaries: [CountryInfo] = [
        // North America
        CountryInfo(name: "United States", code: "US", 
                   bounds: BoundingBox(minLat: 24.396308, maxLat: 71.538800, minLon: -179.148909, maxLon: -66.885444),
                   majorCities: [
                       CityInfo(name: "New York", lat: 40.7128, lon: -74.0060),
                       CityInfo(name: "Los Angeles", lat: 34.0522, lon: -118.2437),
                       CityInfo(name: "Chicago", lat: 41.8781, lon: -87.6298),
                       CityInfo(name: "Houston", lat: 29.7604, lon: -95.3698),
                       CityInfo(name: "Phoenix", lat: 33.4484, lon: -112.0740),
                       CityInfo(name: "Philadelphia", lat: 39.9526, lon: -75.1652),
                       CityInfo(name: "San Antonio", lat: 29.4241, lon: -98.4936),
                       CityInfo(name: "San Diego", lat: 32.7157, lon: -117.1611),
                       CityInfo(name: "Dallas", lat: 32.7767, lon: -96.7970),
                       CityInfo(name: "San Francisco", lat: 37.7749, lon: -122.4194),
                       CityInfo(name: "Austin", lat: 30.2672, lon: -97.7431),
                       CityInfo(name: "Jacksonville", lat: 30.3322, lon: -81.6557),
                       CityInfo(name: "Fort Worth", lat: 32.7555, lon: -97.3308),
                       CityInfo(name: "Columbus", lat: 39.9612, lon: -82.9988),
                       CityInfo(name: "Charlotte", lat: 35.2271, lon: -80.8431),
                       CityInfo(name: "Seattle", lat: 47.6062, lon: -122.3321),
                       CityInfo(name: "Denver", lat: 39.7392, lon: -104.9903),
                       CityInfo(name: "Boston", lat: 42.3601, lon: -71.0589),
                       CityInfo(name: "Nashville", lat: 36.1627, lon: -86.7816),
                       CityInfo(name: "Portland", lat: 45.5152, lon: -122.6784),
                       CityInfo(name: "Las Vegas", lat: 36.1699, lon: -115.1398),
                       CityInfo(name: "Miami", lat: 25.7617, lon: -80.1918)
                   ]),
        CountryInfo(name: "Canada", code: "CA", 
                   bounds: BoundingBox(minLat: 41.676555, maxLat: 83.110626, minLon: -141.00187, maxLon: -52.648099),
                   majorCities: [
                       CityInfo(name: "Toronto", lat: 43.6532, lon: -79.3832),
                       CityInfo(name: "Montreal", lat: 45.5017, lon: -73.5673),
                       CityInfo(name: "Vancouver", lat: 49.2827, lon: -123.1207),
                       CityInfo(name: "Calgary", lat: 51.0447, lon: -114.0719),
                       CityInfo(name: "Ottawa", lat: 45.4215, lon: -75.6972),
                       CityInfo(name: "Edmonton", lat: 53.5461, lon: -113.4938),
                       CityInfo(name: "Mississauga", lat: 43.5890, lon: -79.6441),
                       CityInfo(name: "Winnipeg", lat: 49.8951, lon: -97.1384),
                       CityInfo(name: "Quebec City", lat: 46.8139, lon: -71.2080),
                       CityInfo(name: "Hamilton", lat: 43.2557, lon: -79.8711)
                   ]),
        CountryInfo(name: "Mexico", code: "MX", 
                   bounds: BoundingBox(minLat: 14.532866, maxLat: 32.716759, minLon: -118.453949, maxLon: -86.703392),
                   majorCities: [
                       CityInfo(name: "Mexico City", lat: 19.4326, lon: -99.1332),
                       CityInfo(name: "Guadalajara", lat: 20.6597, lon: -103.3496),
                       CityInfo(name: "Monterrey", lat: 25.6866, lon: -100.3161),
                       CityInfo(name: "Cancun", lat: 21.1619, lon: -86.8515),
                       CityInfo(name: "Tijuana", lat: 32.5149, lon: -117.0382)
                   ]),
        
        // Europe
        CountryInfo(name: "Germany", code: "DE", 
                   bounds: BoundingBox(minLat: 47.270111, maxLat: 55.058347, minLon: 5.866944, maxLon: 15.041896),
                   majorCities: [
                       CityInfo(name: "Berlin", lat: 52.5200, lon: 13.4050),
                       CityInfo(name: "Munich", lat: 48.1351, lon: 11.5820),
                       CityInfo(name: "Hamburg", lat: 53.5511, lon: 9.9937),
                       CityInfo(name: "Cologne", lat: 50.9375, lon: 6.9603),
                       CityInfo(name: "Frankfurt", lat: 50.1109, lon: 8.6821),
                       CityInfo(name: "Stuttgart", lat: 48.7758, lon: 9.1829),
                       CityInfo(name: "Dusseldorf", lat: 51.2277, lon: 6.7735),
                       CityInfo(name: "Dortmund", lat: 51.5136, lon: 7.4653),
                       CityInfo(name: "Essen", lat: 51.4556, lon: 7.0116),
                       CityInfo(name: "Leipzig", lat: 51.3397, lon: 12.3731)
                   ]),
        CountryInfo(name: "France", code: "FR", 
                   bounds: BoundingBox(minLat: 41.303, maxLat: 51.124, minLon: -5.225, maxLon: 9.662),
                   majorCities: [
                       CityInfo(name: "Paris", lat: 48.8566, lon: 2.3522),
                       CityInfo(name: "Marseille", lat: 43.2965, lon: 5.3698),
                       CityInfo(name: "Lyon", lat: 45.7640, lon: 4.8357),
                       CityInfo(name: "Toulouse", lat: 43.6047, lon: 1.4442),
                       CityInfo(name: "Nice", lat: 43.7102, lon: 7.2620),
                       CityInfo(name: "Nantes", lat: 47.2184, lon: -1.5536),
                       CityInfo(name: "Strasbourg", lat: 48.5734, lon: 7.7521),
                       CityInfo(name: "Montpellier", lat: 43.6108, lon: 3.8767),
                       CityInfo(name: "Bordeaux", lat: 44.8378, lon: -0.5792),
                       CityInfo(name: "Lille", lat: 50.6292, lon: 3.0573)
                   ]),
        CountryInfo(name: "United Kingdom", code: "GB", 
                   bounds: BoundingBox(minLat: 49.674, maxLat: 61.061, minLon: -8.649, maxLon: 1.768),
                   majorCities: [
                       CityInfo(name: "London", lat: 51.5074, lon: -0.1278),
                       CityInfo(name: "Birmingham", lat: 52.4862, lon: -1.8904),
                       CityInfo(name: "Glasgow", lat: 55.8642, lon: -4.2518),
                       CityInfo(name: "Liverpool", lat: 53.4084, lon: -2.9916),
                       CityInfo(name: "Bristol", lat: 51.4545, lon: -2.5879),
                       CityInfo(name: "Manchester", lat: 53.4808, lon: -2.2426),
                       CityInfo(name: "Sheffield", lat: 53.3811, lon: -1.4701),
                       CityInfo(name: "Leeds", lat: 53.8008, lon: -1.5491),
                       CityInfo(name: "Edinburgh", lat: 55.9533, lon: -3.1883),
                       CityInfo(name: "Leicester", lat: 52.6369, lon: -1.1398)
                   ]),
        CountryInfo(name: "Spain", code: "ES", 
                   bounds: BoundingBox(minLat: 35.173, maxLat: 43.791, minLon: -9.301, maxLon: 4.327),
                   majorCities: [
                       CityInfo(name: "Madrid", lat: 40.4168, lon: -3.7038),
                       CityInfo(name: "Barcelona", lat: 41.3851, lon: 2.1734),
                       CityInfo(name: "Valencia", lat: 39.4699, lon: -0.3763),
                       CityInfo(name: "Seville", lat: 37.3891, lon: -5.9845),
                       CityInfo(name: "Zaragoza", lat: 41.6488, lon: -0.8891),
                       CityInfo(name: "Malaga", lat: 36.7213, lon: -4.4214),
                       CityInfo(name: "Murcia", lat: 37.9922, lon: -1.1307),
                       CityInfo(name: "Palma", lat: 39.5696, lon: 2.6502),
                       CityInfo(name: "Las Palmas", lat: 28.1248, lon: -15.4300),
                       CityInfo(name: "Bilbao", lat: 43.2627, lon: -2.9253)
                   ]),
        CountryInfo(name: "Italy", code: "IT", 
                   bounds: BoundingBox(minLat: 35.493, maxLat: 47.092, minLon: 6.627, maxLon: 18.521),
                   majorCities: [
                       CityInfo(name: "Rome", lat: 41.9028, lon: 12.4964),
                       CityInfo(name: "Milan", lat: 45.4642, lon: 9.1900),
                       CityInfo(name: "Naples", lat: 40.8518, lon: 14.2681),
                       CityInfo(name: "Turin", lat: 45.0703, lon: 7.6869),
                       CityInfo(name: "Palermo", lat: 38.1157, lon: 13.3615),
                       CityInfo(name: "Genoa", lat: 44.4056, lon: 8.9463),
                       CityInfo(name: "Bologna", lat: 44.4949, lon: 11.3426),
                       CityInfo(name: "Florence", lat: 43.7696, lon: 11.2558),
                       CityInfo(name: "Bari", lat: 41.1171, lon: 16.8719),
                       CityInfo(name: "Catania", lat: 37.5079, lon: 15.0830)
                   ]),
        CountryInfo(name: "Netherlands", code: "NL", 
                   bounds: BoundingBox(minLat: 50.803, maxLat: 53.555, minLon: 3.314, maxLon: 7.227),
                   majorCities: [
                       CityInfo(name: "Amsterdam", lat: 52.3676, lon: 4.9041),
                       CityInfo(name: "Rotterdam", lat: 51.9244, lon: 4.4777),
                       CityInfo(name: "The Hague", lat: 52.0705, lon: 4.3007),
                       CityInfo(name: "Utrecht", lat: 52.0907, lon: 5.1214),
                       CityInfo(name: "Eindhoven", lat: 51.4416, lon: 5.4697),
                       CityInfo(name: "Tilburg", lat: 51.5555, lon: 5.0913),
                       CityInfo(name: "Groningen", lat: 53.2194, lon: 6.5665),
                       CityInfo(name: "Almere", lat: 52.3508, lon: 5.2647),
                       CityInfo(name: "Breda", lat: 51.5719, lon: 4.7683),
                       CityInfo(name: "Nijmegen", lat: 51.8426, lon: 5.8518)
                   ]),
        CountryInfo(name: "Switzerland", code: "CH", 
                   bounds: BoundingBox(minLat: 45.818, maxLat: 47.808, minLon: 5.957, maxLon: 10.492),
                   majorCities: [
                       CityInfo(name: "Zurich", lat: 47.3769, lon: 8.5417),
                       CityInfo(name: "Geneva", lat: 46.2044, lon: 6.1432),
                       CityInfo(name: "Basel", lat: 47.5596, lon: 7.5886),
                       CityInfo(name: "Lausanne", lat: 46.5197, lon: 6.6323),
                       CityInfo(name: "Bern", lat: 46.9481, lon: 7.4474),
                       CityInfo(name: "Winterthur", lat: 47.5034, lon: 8.7240),
                       CityInfo(name: "Lucerne", lat: 47.0502, lon: 8.3093),
                       CityInfo(name: "St. Gallen", lat: 47.4245, lon: 9.3767),
                       CityInfo(name: "Lugano", lat: 46.0037, lon: 8.9511),
                       CityInfo(name: "Biel", lat: 47.1368, lon: 7.2448)
                   ]),
        CountryInfo(name: "Austria", code: "AT", 
                   bounds: BoundingBox(minLat: 46.372, maxLat: 49.021, minLon: 9.531, maxLon: 17.161),
                   majorCities: [
                       CityInfo(name: "Vienna", lat: 48.2082, lon: 16.3738),
                       CityInfo(name: "Graz", lat: 47.0707, lon: 15.4395),
                       CityInfo(name: "Linz", lat: 48.3069, lon: 14.2858),
                       CityInfo(name: "Salzburg", lat: 47.8095, lon: 13.0550),
                       CityInfo(name: "Innsbruck", lat: 47.2692, lon: 11.4041)
                   ]),
        CountryInfo(name: "Belgium", code: "BE", 
                   bounds: BoundingBox(minLat: 49.497, maxLat: 51.505, minLon: 2.546, maxLon: 6.408),
                   majorCities: [
                       CityInfo(name: "Brussels", lat: 50.8503, lon: 4.3517),
                       CityInfo(name: "Antwerp", lat: 51.2194, lon: 4.4025),
                       CityInfo(name: "Ghent", lat: 51.0543, lon: 3.7174),
                       CityInfo(name: "Charleroi", lat: 50.4108, lon: 4.4446),
                       CityInfo(name: "Liege", lat: 50.6326, lon: 5.5797)
                   ]),
        CountryInfo(name: "Denmark", code: "DK", 
                   bounds: BoundingBox(minLat: 54.559, maxLat: 57.751, minLon: 8.075, maxLon: 15.158),
                   majorCities: [
                       CityInfo(name: "Copenhagen", lat: 55.6761, lon: 12.5683),
                       CityInfo(name: "Aarhus", lat: 56.1629, lon: 10.2039),
                       CityInfo(name: "Odense", lat: 55.4038, lon: 10.4024),
                       CityInfo(name: "Aalborg", lat: 57.0488, lon: 9.9217),
                       CityInfo(name: "Esbjerg", lat: 55.4667, lon: 8.4500)
                   ]),
        CountryInfo(name: "Sweden", code: "SE", 
                   bounds: BoundingBox(minLat: 55.337, maxLat: 69.060, minLon: 11.118, maxLon: 24.167),
                   majorCities: [
                       CityInfo(name: "Stockholm", lat: 59.3293, lon: 18.0686),
                       CityInfo(name: "Gothenburg", lat: 57.7089, lon: 11.9746),
                       CityInfo(name: "Malmo", lat: 55.6050, lon: 13.0038),
                       CityInfo(name: "Uppsala", lat: 59.8586, lon: 17.6389),
                       CityInfo(name: "Vasteras", lat: 59.6099, lon: 16.5448)
                   ]),
        CountryInfo(name: "Norway", code: "NO", 
                   bounds: BoundingBox(minLat: 57.977, maxLat: 80.757, minLon: 4.650, maxLon: 31.078),
                   majorCities: [
                       CityInfo(name: "Oslo", lat: 59.9139, lon: 10.7522),
                       CityInfo(name: "Bergen", lat: 60.3913, lon: 5.3221),
                       CityInfo(name: "Trondheim", lat: 63.4305, lon: 10.3951),
                       CityInfo(name: "Stavanger", lat: 58.9700, lon: 5.7331),
                       CityInfo(name: "Baerum", lat: 59.8939, lon: 10.5464)
                   ]),
        CountryInfo(name: "Finland", code: "FI", 
                   bounds: BoundingBox(minLat: 59.808, maxLat: 70.092, minLon: 20.556, maxLon: 31.587),
                   majorCities: [
                       CityInfo(name: "Helsinki", lat: 60.1699, lon: 24.9384),
                       CityInfo(name: "Espoo", lat: 60.2055, lon: 24.6559),
                       CityInfo(name: "Tampere", lat: 61.4991, lon: 23.7871),
                       CityInfo(name: "Vantaa", lat: 60.2934, lon: 25.0378),
                       CityInfo(name: "Oulu", lat: 65.0121, lon: 25.4651)
                   ]),
        CountryInfo(name: "Poland", code: "PL", 
                   bounds: BoundingBox(minLat: 49.006, maxLat: 54.836, minLon: 14.123, maxLon: 24.150),
                   majorCities: [
                       CityInfo(name: "Warsaw", lat: 52.2297, lon: 21.0122),
                       CityInfo(name: "Krakow", lat: 50.0647, lon: 19.9450),
                       CityInfo(name: "Lodz", lat: 51.7592, lon: 19.4560),
                       CityInfo(name: "Wroclaw", lat: 51.1079, lon: 17.0385),
                       CityInfo(name: "Poznan", lat: 52.4064, lon: 16.9252),
                       CityInfo(name: "Gdansk", lat: 54.3520, lon: 18.6466),
                       CityInfo(name: "Szczecin", lat: 53.4285, lon: 14.5528),
                       CityInfo(name: "Bydgoszcz", lat: 53.1235, lon: 18.0084),
                       CityInfo(name: "Lublin", lat: 51.2465, lon: 22.5684),
                       CityInfo(name: "Katowice", lat: 50.2649, lon: 19.0238)
                   ]),
        CountryInfo(name: "Czech Republic", code: "CZ", 
                   bounds: BoundingBox(minLat: 48.551, maxLat: 51.055, minLon: 12.096, maxLon: 18.877),
                   majorCities: [
                       CityInfo(name: "Prague", lat: 50.0755, lon: 14.4378),
                       CityInfo(name: "Brno", lat: 49.1951, lon: 16.6068),
                       CityInfo(name: "Ostrava", lat: 49.8209, lon: 18.2625),
                       CityInfo(name: "Plzen", lat: 49.7384, lon: 13.3736),
                       CityInfo(name: "Liberec", lat: 50.7663, lon: 15.0543)
                   ]),
        CountryInfo(name: "Hungary", code: "HU", 
                   bounds: BoundingBox(minLat: 45.737, maxLat: 48.585, minLon: 16.114, maxLon: 22.906),
                   majorCities: [
                       CityInfo(name: "Budapest", lat: 47.4979, lon: 19.0402),
                       CityInfo(name: "Debrecen", lat: 47.5316, lon: 21.6273),
                       CityInfo(name: "Szeged", lat: 46.2530, lon: 20.1414),
                       CityInfo(name: "Miskolc", lat: 48.1034, lon: 20.7784),
                       CityInfo(name: "Pecs", lat: 46.0727, lon: 18.2330)
                   ]),
        CountryInfo(name: "Portugal", code: "PT", 
                   bounds: BoundingBox(minLat: 36.838, maxLat: 42.280, minLon: -9.526, maxLon: -6.189),
                   majorCities: [
                       CityInfo(name: "Lisbon", lat: 38.7223, lon: -9.1393),
                       CityInfo(name: "Porto", lat: 41.1579, lon: -8.6291),
                       CityInfo(name: "Vila Nova de Gaia", lat: 41.1239, lon: -8.6118),
                       CityInfo(name: "Amadora", lat: 38.7538, lon: -9.2342),
                       CityInfo(name: "Braga", lat: 41.5518, lon: -8.4229)
                   ]),
        CountryInfo(name: "Slovenia", code: "SI", 
                   bounds: BoundingBox(minLat: 45.421, maxLat: 46.877, minLon: 13.375, maxLon: 16.610),
                   majorCities: [
                       CityInfo(name: "Ljubljana", lat: 46.0569, lon: 14.5058),
                       CityInfo(name: "Maribor", lat: 46.5547, lon: 15.6459),
                       CityInfo(name: "Celje", lat: 46.2311, lon: 15.2683),
                       CityInfo(name: "Kranj", lat: 46.2395, lon: 14.3555),
                       CityInfo(name: "Velenje", lat: 46.3590, lon: 15.1116)
                   ]),
        CountryInfo(name: "Iceland", code: "IS", 
                   bounds: BoundingBox(minLat: 63.236, maxLat: 66.574, minLon: -24.533, maxLon: -13.495),
                   majorCities: [
                       CityInfo(name: "Reykjavik", lat: 64.1466, lon: -21.9426),
                       CityInfo(name: "Kopavogur", lat: 64.1125, lon: -21.9110),
                       CityInfo(name: "Hafnarfjordur", lat: 64.0671, lon: -21.9506),
                       CityInfo(name: "Akureyri", lat: 65.6835, lon: -18.0878),
                       CityInfo(name: "Reykjanesbaer", lat: 63.9942, lon: -22.5541)
                   ]),
        
        // Asia-Pacific
        CountryInfo(name: "Japan", code: "JP", 
                   bounds: BoundingBox(minLat: 24.045, maxLat: 45.522, minLon: 122.934, maxLon: 153.987),
                   majorCities: [
                       CityInfo(name: "Tokyo", lat: 35.6762, lon: 139.6503),
                       CityInfo(name: "Yokohama", lat: 35.4437, lon: 139.6380),
                       CityInfo(name: "Osaka", lat: 34.6937, lon: 135.5023),
                       CityInfo(name: "Nagoya", lat: 35.1815, lon: 136.9066),
                       CityInfo(name: "Sapporo", lat: 43.0642, lon: 141.3469),
                       CityInfo(name: "Fukuoka", lat: 33.5904, lon: 130.4017),
                       CityInfo(name: "Kobe", lat: 34.6901, lon: 135.1956),
                       CityInfo(name: "Kyoto", lat: 35.0116, lon: 135.7681),
                       CityInfo(name: "Kawasaki", lat: 35.5308, lon: 139.7029),
                       CityInfo(name: "Saitama", lat: 35.8617, lon: 139.6455)
                   ]),
        CountryInfo(name: "Australia", code: "AU", 
                   bounds: BoundingBox(minLat: -43.634, maxLat: -10.683, minLon: 113.338, maxLon: 153.569),
                   majorCities: [
                       CityInfo(name: "Sydney", lat: -33.8688, lon: 151.2093),
                       CityInfo(name: "Melbourne", lat: -37.8136, lon: 144.9631),
                       CityInfo(name: "Brisbane", lat: -27.4698, lon: 153.0251),
                       CityInfo(name: "Perth", lat: -31.9505, lon: 115.8605),
                       CityInfo(name: "Adelaide", lat: -34.9285, lon: 138.6007),
                       CityInfo(name: "Gold Coast", lat: -28.0167, lon: 153.4000),
                       CityInfo(name: "Newcastle", lat: -32.9267, lon: 151.7789),
                       CityInfo(name: "Canberra", lat: -35.2809, lon: 149.1300),
                       CityInfo(name: "Sunshine Coast", lat: -26.6500, lon: 153.0667),
                       CityInfo(name: "Wollongong", lat: -34.4278, lon: 150.8931)
                   ]),
        CountryInfo(name: "New Zealand", code: "NZ", 
                   bounds: BoundingBox(minLat: -47.286, maxLat: -34.389, minLon: 166.509, maxLon: 178.517),
                   majorCities: [
                       CityInfo(name: "Auckland", lat: -36.8485, lon: 174.7633),
                       CityInfo(name: "Wellington", lat: -41.2865, lon: 174.7762),
                       CityInfo(name: "Christchurch", lat: -43.5321, lon: 172.6362),
                       CityInfo(name: "Hamilton", lat: -37.7870, lon: 175.2793),
                       CityInfo(name: "Tauranga", lat: -37.6878, lon: 176.1651)
                   ]),
        CountryInfo(name: "Singapore", code: "SG", 
                   bounds: BoundingBox(minLat: 1.158, maxLat: 1.470, minLon: 103.594, maxLon: 104.089),
                   majorCities: [
                       CityInfo(name: "Singapore", lat: 1.3521, lon: 103.8198)
                   ]),
        CountryInfo(name: "South Korea", code: "KR", 
                   bounds: BoundingBox(minLat: 33.190, maxLat: 38.612, minLon: 125.887, maxLon: 129.584),
                   majorCities: [
                       CityInfo(name: "Seoul", lat: 37.5665, lon: 126.9780),
                       CityInfo(name: "Busan", lat: 35.1796, lon: 129.0756),
                       CityInfo(name: "Incheon", lat: 37.4563, lon: 126.7052),
                       CityInfo(name: "Daegu", lat: 35.8714, lon: 128.6014),
                       CityInfo(name: "Daejeon", lat: 36.3504, lon: 127.3845)
                   ]),
        CountryInfo(name: "China", code: "CN", 
                   bounds: BoundingBox(minLat: 18.197, maxLat: 53.561, minLon: 73.499, maxLon: 135.095),
                   majorCities: [
                       CityInfo(name: "Beijing", lat: 39.9042, lon: 116.4074),
                       CityInfo(name: "Shanghai", lat: 31.2304, lon: 121.4737),
                       CityInfo(name: "Guangzhou", lat: 23.1291, lon: 113.2644),
                       CityInfo(name: "Shenzhen", lat: 22.5431, lon: 114.0579),
                       CityInfo(name: "Chongqing", lat: 29.4316, lon: 106.9123),
                       CityInfo(name: "Tianjin", lat: 39.3434, lon: 117.3616),
                       CityInfo(name: "Wuhan", lat: 30.5928, lon: 114.3055),
                       CityInfo(name: "Dongguan", lat: 23.0489, lon: 113.7447),
                       CityInfo(name: "Chengdu", lat: 30.5728, lon: 104.0668),
                       CityInfo(name: "Nanjing", lat: 32.0603, lon: 118.7969)
                   ]),
        CountryInfo(name: "India", code: "IN", 
                   bounds: BoundingBox(minLat: 8.068, maxLat: 37.097, minLon: 68.133, maxLon: 97.395),
                   majorCities: [
                       CityInfo(name: "Mumbai", lat: 19.0760, lon: 72.8777),
                       CityInfo(name: "Delhi", lat: 28.7041, lon: 77.1025),
                       CityInfo(name: "Bangalore", lat: 12.9716, lon: 77.5946),
                       CityInfo(name: "Hyderabad", lat: 17.3850, lon: 78.4867),
                       CityInfo(name: "Ahmedabad", lat: 23.0225, lon: 72.5714),
                       CityInfo(name: "Chennai", lat: 13.0827, lon: 80.2707),
                       CityInfo(name: "Kolkata", lat: 22.5726, lon: 88.3639),
                       CityInfo(name: "Surat", lat: 21.1702, lon: 72.8311),
                       CityInfo(name: "Pune", lat: 18.5204, lon: 73.8567),
                       CityInfo(name: "Jaipur", lat: 26.9124, lon: 75.7873)
                   ]),
        
        // Middle East & Africa
        CountryInfo(name: "United Arab Emirates", code: "AE", 
                   bounds: BoundingBox(minLat: 22.633, maxLat: 26.084, minLon: 51.583, maxLon: 56.397),
                   majorCities: [
                       CityInfo(name: "Dubai", lat: 25.2048, lon: 55.2708),
                       CityInfo(name: "Abu Dhabi", lat: 24.2992, lon: 54.6970),
                       CityInfo(name: "Sharjah", lat: 25.3463, lon: 55.4209),
                       CityInfo(name: "Al Ain", lat: 24.2075, lon: 55.7447),
                       CityInfo(name: "Ajman", lat: 25.4052, lon: 55.5136)
                   ]),
        CountryInfo(name: "Saudi Arabia", code: "SA", 
                   bounds: BoundingBox(minLat: 16.002, maxLat: 32.154, minLon: 34.495, maxLon: 55.667),
                   majorCities: [
                       CityInfo(name: "Riyadh", lat: 24.7136, lon: 46.6753),
                       CityInfo(name: "Jeddah", lat: 21.3099, lon: 39.1925),
                       CityInfo(name: "Mecca", lat: 21.3891, lon: 39.8579),
                       CityInfo(name: "Medina", lat: 24.5247, lon: 39.5692),
                       CityInfo(name: "Dammam", lat: 26.3927, lon: 49.9777)
                   ]),
        CountryInfo(name: "Israel", code: "IL", 
                   bounds: BoundingBox(minLat: 29.496, maxLat: 33.341, minLon: 34.267, maxLon: 35.896),
                   majorCities: [
                       CityInfo(name: "Jerusalem", lat: 31.7683, lon: 35.2137),
                       CityInfo(name: "Tel Aviv", lat: 32.0853, lon: 34.7818),
                       CityInfo(name: "Haifa", lat: 32.7940, lon: 34.9896),
                       CityInfo(name: "Rishon LeZion", lat: 31.9730, lon: 34.8065),
                       CityInfo(name: "Petah Tikva", lat: 32.0878, lon: 34.8878)
                   ]),
        CountryInfo(name: "South Africa", code: "ZA", 
                   bounds: BoundingBox(minLat: -34.839, maxLat: -22.125, minLon: 16.344, maxLon: 32.895),
                   majorCities: [
                       CityInfo(name: "Johannesburg", lat: -26.2041, lon: 28.0473),
                       CityInfo(name: "Cape Town", lat: -33.9249, lon: 18.4241),
                       CityInfo(name: "Durban", lat: -29.8587, lon: 31.0218),
                       CityInfo(name: "Pretoria", lat: -25.7479, lon: 28.2293),
                       CityInfo(name: "Port Elizabeth", lat: -33.9608, lon: 25.6022)
                   ]),
        
        // South America
        CountryInfo(name: "Brazil", code: "BR", 
                   bounds: BoundingBox(minLat: -33.751, maxLat: 5.272, minLon: -73.985, maxLon: -28.847),
                   majorCities: [
                       CityInfo(name: "Sao Paulo", lat: -23.5558, lon: -46.6396),
                       CityInfo(name: "Rio de Janeiro", lat: -22.9068, lon: -43.1729),
                       CityInfo(name: "Brasilia", lat: -15.8267, lon: -47.9218),
                       CityInfo(name: "Salvador", lat: -12.9714, lon: -38.5014),
                       CityInfo(name: "Fortaleza", lat: -3.7319, lon: -38.5267),
                       CityInfo(name: "Belo Horizonte", lat: -19.8157, lon: -43.9542),
                       CityInfo(name: "Manaus", lat: -3.1190, lon: -60.0217),
                       CityInfo(name: "Curitiba", lat: -25.4284, lon: -49.2733),
                       CityInfo(name: "Recife", lat: -8.0476, lon: -34.8770),
                       CityInfo(name: "Porto Alegre", lat: -30.0346, lon: -51.2177)
                   ]),
        CountryInfo(name: "Argentina", code: "AR", 
                   bounds: BoundingBox(minLat: -55.061, maxLat: -21.781, minLon: -73.560, maxLon: -53.591),
                   majorCities: [
                       CityInfo(name: "Buenos Aires", lat: -34.6118, lon: -58.3960),
                       CityInfo(name: "Cordoba", lat: -31.4201, lon: -64.1888),
                       CityInfo(name: "Rosario", lat: -32.9442, lon: -60.6505),
                       CityInfo(name: "Mendoza", lat: -32.8908, lon: -68.8272),
                       CityInfo(name: "La Plata", lat: -34.9215, lon: -57.9545)
                   ]),
        CountryInfo(name: "Chile", code: "CL", 
                   bounds: BoundingBox(minLat: -55.926, maxLat: -17.507, minLon: -109.454, maxLon: -66.417),
                   majorCities: [
                       CityInfo(name: "Santiago", lat: -33.4489, lon: -70.6693),
                       CityInfo(name: "Valparaiso", lat: -33.0458, lon: -71.6197),
                       CityInfo(name: "Concepcion", lat: -36.8270, lon: -73.0498),
                       CityInfo(name: "La Serena", lat: -29.9027, lon: -71.2519),
                       CityInfo(name: "Antofagasta", lat: -23.6509, lon: -70.3975)
                   ])
    ]
    
    // MARK: - Supporting Structures
    
    private struct CountryInfo {
        let name: String
        let code: String
        let bounds: BoundingBox
        let majorCities: [CityInfo]
    }
    
    private struct BoundingBox {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double
        
        func contains(lat: Double, lon: Double) -> Bool {
            return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
        }
    }
    
    private struct CityInfo {
        let name: String
        let lat: Double
        let lon: Double
    }
    
    // MARK: - Public Interface
    
    struct GeocodeResult {
        let country: String
        let city: String
        let confidence: Double // 0.0 to 1.0
    }
    
    /// Fast offline geocoding using local database
    /// Returns country and city for given coordinates
    static func geocode(latitude: Double, longitude: Double) -> GeocodeResult {
        
        // Find matching countries by bounding box
        let matchingCountries = countryBoundaries.filter { country in
            country.bounds.contains(lat: latitude, lon: longitude)
        }
        
        guard let country = matchingCountries.first else {
            // Fallback for coordinates not in database
            return GeocodeResult(
                country: "Unknown",
                city: "Unknown",
                confidence: 0.0
            )
        }
        
        // Find closest city within the country
        let closestCity = findClosestCity(
            lat: latitude,
            lon: longitude,
            in: country.majorCities
        )
        
        // Be much more conservative about city assignment
        // Only assign a city if it's reasonably close (within 25km for large cities, 10km for smaller ones)
        let cityName: String
        let confidence: Double
        
        if closestCity.distance <= 10.0 {
            // Very close to a major city
            cityName = closestCity.city
            confidence = 0.95
        } else if closestCity.distance <= 25.0 {
            // Reasonably close to a major city  
            cityName = closestCity.city
            confidence = 0.80
        } else if closestCity.distance <= 50.0 {
            // Moderately close - use region name instead of specific city
            cityName = getRegionName(country: country.name, closestCity: closestCity.city)
            confidence = 0.70
        } else {
            // Too far from any major city - just use country
            cityName = "Other \(country.name)"
            confidence = 0.60
        }
        
        return GeocodeResult(
            country: country.name,
            city: cityName,
            confidence: confidence
        )
    }
    
    /// Get a region name for locations far from major cities
    private static func getRegionName(country: String, closestCity: String) -> String {
        switch country {
        case "United States":
            // Use state/region names for remote areas
            return "Rural \(country)"
        case "Germany":
            return "Rural \(country)"
        case "France": 
            return "Rural \(country)"
        case "United Kingdom":
            return "Rural \(country)"
        default:
            return "Rural \(country)"
        }
    }
    
    // MARK: - Private Helpers
    
    private struct CityDistance {
        let city: String
        let distance: Double // in km
    }
    
    private static func findClosestCity(lat: Double, lon: Double, in cities: [CityInfo]) -> CityDistance {
        guard !cities.isEmpty else {
            return CityDistance(city: "Unknown", distance: Double.infinity)
        }
        
        var closest = cities[0]
        var minDistance = distance(from: (lat, lon), to: (closest.lat, closest.lon))
        
        for city in cities.dropFirst() {
            let dist = distance(from: (lat, lon), to: (city.lat, city.lon))
            if dist < minDistance {
                minDistance = dist
                closest = city
            }
        }
        
        return CityDistance(city: closest.name, distance: minDistance)
    }
    
    /// Calculate distance between two coordinates using Haversine formula
    private static func distance(from coord1: (lat: Double, lon: Double), to coord2: (lat: Double, lon: Double)) -> Double {
        let R = 6371.0 // Earth's radius in kilometers
        
        let lat1Rad = coord1.lat * .pi / 180
        let lat2Rad = coord2.lat * .pi / 180
        let deltaLatRad = (coord2.lat - coord1.lat) * .pi / 180
        let deltaLonRad = (coord2.lon - coord1.lon) * .pi / 180
        
        let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLonRad / 2) * sin(deltaLonRad / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return R * c
    }
}
