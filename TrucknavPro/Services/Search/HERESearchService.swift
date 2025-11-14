//
//  HERESearchService.swift
//  TruckNavPro
//
//  HERE Geocoding & Search API v7 - Fallback for TomTom
//

import Foundation
import CoreLocation

class HERESearchService {

    private let apiKey: String
    private let discoverURL = "https://discover.search.hereapi.com/v1"
    private let browseURL = "https://browse.search.hereapi.com/v1"

    // Track current search task to prevent race conditions
    private var currentSearchTask: URLSessionDataTask?

    // Truck-specific POI categories (mapped from TomTom)
    enum TruckCategory: String, CaseIterable {
        case truckStop = "700-7600-0116"        // Truck Stop
        case restArea = "800-8500-0000"         // Rest Area
        case weighStation = "700-7851-0000"     // Weigh Station
        case truckParking = "700-7600-0000"     // Parking
        case fuelStation = "700-7600-0117"      // Gas Station (different code)
        case mechanic = "700-7800-0000"         // Repair Shop
        case hotel = "500-5000-0000"            // Hotel
        case restaurant = "100-1000-0000"       // Restaurant

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
    }

    struct HERESearchResult {
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
        print("🗺️ HERE Search Service initialized with API key: \(apiKey.prefix(10))...")

        // Verify API key format
        if apiKey.isEmpty || apiKey == "YOUR_API_KEY_HERE" {
            print("⚠️ WARNING: HERE API key not configured!")
        }
    }

    // MARK: - Free Text Search (Discover API for POIs)

    func searchText(
        _ query: String,
        near coordinate: CLLocationCoordinate2D,
        limit: Int = 10,
        completion: @escaping (Result<[HERESearchResult], Error>) -> Void
    ) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Build URL with HERE Discover API parameters (POI search)
        let urlString = "\(discoverURL)/discover?q=\(encodedQuery)&at=\(coordinate.latitude),\(coordinate.longitude)&limit=\(limit)&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "HERESearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🔍 HERE Discover Search (POI): '\(query)' near \(coordinate)")
        print("🌐 URL: \(url.absoluteString)")

        // Cancel previous search to prevent race conditions
        currentSearchTask?.cancel()

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ HERE Search network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HERE Response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    completion(.failure(NSError(domain: "HERESearch", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    return
                }
            }

            guard let data = data else {
                print("❌ HERE Search: No data received")
                completion(.failure(NSError(domain: "HERESearch", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response preview
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 HERE Response preview: \(jsonString.prefix(500))")
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(HEREDiscoverResponse.self, from: data)

                let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

                let results = response.items.map { item -> HERESearchResult in
                    let itemCoordinate = CLLocationCoordinate2D(
                        latitude: item.position.lat,
                        longitude: item.position.lng
                    )
                    let itemLocation = CLLocation(latitude: item.position.lat, longitude: item.position.lng)
                    let distance = item.distance ?? userLocation.distance(from: itemLocation)

                    // Safely extract phone number with nil-safe optional chaining
                    let phoneNumber = item.contacts?.first?.phone?.first?.value

                    return HERESearchResult(
                        id: item.id,
                        name: item.title,
                        category: item.categories?.first?.name ?? "Place",
                        distance: distance,
                        coordinate: itemCoordinate,
                        address: item.address?.label ?? "Unknown",
                        phone: phoneNumber,
                        categories: item.categories?.map { $0.name } ?? []
                    )
                }

                print("✅ HERE Search found \(results.count) results for '\(query)'")
                completion(.success(results))
            } catch {
                print("❌ HERE Search decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON: \(jsonString)")
                }
                completion(.failure(error))
            }
        }

        // Store and resume task
        currentSearchTask = task
        task.resume()
    }

    // MARK: - Category Search

    func searchCategory(
        _ category: TruckCategory,
        near coordinate: CLLocationCoordinate2D,
        radius: Int = 100000,  // 100km default
        limit: Int = 20,
        completion: @escaping (Result<[HERESearchResult], Error>) -> Void
    ) {
        // Use query term instead of category ID (more reliable for HERE API)
        let queryTerm = getCategoryQueryTerm(for: category)

        searchText(queryTerm, near: coordinate, limit: limit, completion: completion)
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
}

// MARK: - Response Models

// Geocode API Response (simpler, more compatible)
struct HEREGeocodeResponse: Codable {
    struct Item: Codable {
        let id: String
        let title: String
        let resultType: String?
        let position: Position
        let address: Address?

        struct Position: Codable {
            let lat: Double
            let lng: Double
        }

        struct Address: Codable {
            let label: String
            let countryCode: String?
            let countryName: String?
            let state: String?
            let city: String?
            let postalCode: String?
            let street: String?
        }
    }

    let items: [Item]
}

// Discover API Response (legacy, kept for reference)
struct HEREDiscoverResponse: Codable {
    struct Item: Codable {
        let id: String
        let title: String
        let distance: Double?
        let position: Position
        let address: Address?
        let categories: [Category]?
        let contacts: [Contact]?

        struct Position: Codable {
            let lat: Double
            let lng: Double
        }

        struct Address: Codable {
            let label: String
            let countryCode: String?
            let countryName: String?
            let state: String?
            let city: String?
            let postalCode: String?
            let street: String?
        }

        struct Category: Codable {
            let id: String
            let name: String
            let primary: Bool?
        }

        struct Contact: Codable {
            let phone: [Phone]?
            let www: [Website]?

            struct Phone: Codable {
                let value: String
                let categories: [Category]?

                struct Category: Codable {
                    let id: String
                }
            }

            struct Website: Codable {
                let value: String
            }
        }
    }

    let items: [Item]
}
