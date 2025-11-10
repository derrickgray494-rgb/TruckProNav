//
//  TomTomSearchService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation
import MapboxSearchUI

class TomTomSearchService {

    private let apiKey: String
    private let baseURL = "https://api.tomtom.com/search/2"

    // Truck-specific POI categories
    enum TruckCategory: Int, CaseIterable {
        case truckStop = 7315
        case restArea = 7365
        case weighStation = 7395
        case truckParking = 7318
        case fuelStation = 7311
        case mechanic = 7303
        case hotel = 7313
        case restaurant = 7315000

        var displayName: String {
            switch self {
            case .truckStop: return "Truck Stops"
            case .restArea: return "Rest Areas"
            case .weighStation: return "Weigh Stations"
            case .truckParking: return "Truck Parking"
            case .fuelStation: return "Fuel Stations"
            case .mechanic: return "Repair Shops"
            case .hotel: return "Hotels"
            case .restaurant: return "Restaurants"
            }
        }

        var icon: String {
            switch self {
            case .truckStop: return "fuelpump.circle.fill"
            case .restArea: return "bed.double.fill"
            case .weighStation: return "scalemass.fill"
            case .truckParking: return "parkingsign.circle.fill"
            case .fuelStation: return "fuelpump.fill"
            case .mechanic: return "wrench.and.screwdriver.fill"
            case .hotel: return "building.2.fill"
            case .restaurant: return "fork.knife.circle.fill"
            }
        }
    }

    struct TruckSearchResult {
        let id: String
        let name: String
        let category: String
        let distance: Double  // meters
        let coordinate: CLLocationCoordinate2D
        let address: String
        let phone: String?
        let categories: [String]
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        print("🔑 TomTom Search Service initialized with API key: \(apiKey.prefix(10))...")

        // Verify API key format
        if apiKey.isEmpty || apiKey == "YOUR_API_KEY_HERE" {
            print("⚠️ WARNING: TomTom API key not configured!")
        }
    }

    // MARK: - Search by Category (using Fuzzy Search - more reliable)

    func searchCategory(
        _ category: TruckCategory,
        near coordinate: CLLocationCoordinate2D,
        radius: Int = 100000,  // 100km default
        limit: Int = 20,
        completion: @escaping (Result<[TruckSearchResult], Error>) -> Void
    ) {
        // Use fuzzy search with category-specific query terms (more reliable than categorySearch)
        let queryTerm = getCategoryQueryTerm(for: category)

        // Build URL with fuzzy search endpoint
        let urlString = "\(baseURL)/search/\(queryTerm).json?key=\(apiKey)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&radius=\(radius)&limit=\(limit)&typeahead=false"

        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            completion(.failure(NSError(domain: "TomTomSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🔍 TomTom Fuzzy Search: \(category.displayName) (\(queryTerm)) near \(coordinate)")
        print("🌐 URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "TomTomSearch", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Response preview: \(jsonString.prefix(500))")
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SearchResponse.self, from: data)

                let results = response.results.map { result -> TruckSearchResult in
                    TruckSearchResult(
                        id: result.id,
                        name: result.poi?.name ?? result.address?.freeformAddress ?? "Unknown",
                        category: result.poi?.categories?.first ?? category.displayName,
                        distance: result.dist ?? 0,
                        coordinate: CLLocationCoordinate2D(
                            latitude: result.position.lat,
                            longitude: result.position.lon
                        ),
                        address: result.address?.freeformAddress ?? "Unknown",
                        phone: result.poi?.phone,
                        categories: result.poi?.categories ?? []
                    )
                }

                print("✅ Found \(results.count) \(category.displayName)")
                completion(.success(results))
            } catch {
                print("❌ TomTom Search decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    // Get search query term for category
    private func getCategoryQueryTerm(for category: TruckCategory) -> String {
        switch category {
        case .truckStop: return "truck stop"
        case .restArea: return "rest area"
        case .weighStation: return "weigh station"
        case .truckParking: return "truck parking"
        case .fuelStation: return "gas station"
        case .mechanic: return "truck repair"
        case .hotel: return "hotel"
        case .restaurant: return "restaurant"
        }
    }

    // MARK: - Free Text Search (Fuzzy Search)

    func searchText(
        _ query: String,
        near coordinate: CLLocationCoordinate2D,
        limit: Int = 10,
        completion: @escaping (Result<[TruckSearchResult], Error>) -> Void
    ) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/\(encodedQuery).json?key=\(apiKey)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&limit=\(limit)&typeahead=false"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TomTomSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🔍 TomTom Fuzzy Search: '\(query)' near \(coordinate)")
        print("🌐 URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "TomTomSearch", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Response preview: \(jsonString.prefix(500))")
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SearchResponse.self, from: data)

                let results = response.results.map { result -> TruckSearchResult in
                    TruckSearchResult(
                        id: result.id,
                        name: result.poi?.name ?? result.address?.freeformAddress ?? "Unknown",
                        category: result.poi?.categories?.first ?? "Place",
                        distance: result.dist ?? 0,
                        coordinate: CLLocationCoordinate2D(
                            latitude: result.position.lat,
                            longitude: result.position.lon
                        ),
                        address: result.address?.freeformAddress ?? "Unknown",
                        phone: result.poi?.phone,
                        categories: result.poi?.categories ?? []
                    )
                }

                print("✅ Found \(results.count) results for '\(query)'")
                completion(.success(results))
            } catch {
                print("❌ TomTom Search decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Response Models

struct SearchResponse: Codable {
    struct Result: Codable {
        let id: String
        let type: String
        let score: Double
        let dist: Double?
        let poi: POI?
        let address: Address?
        let position: Position

        struct POI: Codable {
            let name: String
            let phone: String?
            let categories: [String]?
        }

        struct Address: Codable {
            let freeformAddress: String
            let municipality: String?
            let countrySubdivision: String?
            let postalCode: String?
            let country: String?
        }

        struct Position: Codable {
            let lat: Double
            let lon: Double
        }
    }

    struct Summary: Codable {
        let queryType: String
        let queryTime: Int
        let numResults: Int
        let totalResults: Int
    }

    let summary: Summary
    let results: [Result]
}
