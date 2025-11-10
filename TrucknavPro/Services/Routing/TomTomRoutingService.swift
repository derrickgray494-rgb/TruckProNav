//
//  TomTomRoutingService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation

// MARK: - Truck Parameters

struct TruckParameters {
    var weight: Int? // kg
    var axleWeight: Int? // kg
    var length: Double? // meters
    var width: Double? // meters
    var height: Double? // meters
    var commercialVehicle: Bool = true
    var loadType: [String]? // e.g., ["USHazmatClass1", "USHazmatClass2"]

    // Route Avoidances
    var avoidTolls: Bool = false
    var avoidMotorways: Bool = false
    var avoidFerries: Bool = false
    var avoidUnpavedRoads: Bool = true
    var avoidTunnels: Bool = false // Enable for hazmat
    var avoidBorderCrossings: Bool = false

    func toQueryParameters() -> [String: String] {
        var params: [String: String] = [:]

        if let weight = weight {
            params["vehicleWeight"] = "\(weight)"
        }
        if let axleWeight = axleWeight {
            params["vehicleAxleWeight"] = "\(axleWeight)"
        }
        if let length = length {
            params["vehicleLength"] = String(format: "%.2f", length)
        }
        if let width = width {
            params["vehicleWidth"] = String(format: "%.2f", width)
        }
        if let height = height {
            params["vehicleHeight"] = String(format: "%.2f", height)
        }
        if commercialVehicle {
            params["vehicleCommercial"] = "true"
        }
        if let loadType = loadType {
            params["vehicleLoadType"] = loadType.joined(separator: ",")
        }

        // Build avoidance list
        var avoidances: [String] = []
        if avoidTolls { avoidances.append("tollRoads") }
        if avoidMotorways { avoidances.append("motorways") }
        if avoidFerries { avoidances.append("ferries") }
        if avoidUnpavedRoads { avoidances.append("unpavedRoads") }
        if avoidTunnels { avoidances.append("tunnels") }
        if avoidBorderCrossings { avoidances.append("borderCrossings") }

        if !avoidances.isEmpty {
            params["avoid"] = avoidances.joined(separator: ",")
        }

        return params
    }
}

// MARK: - TomTom Response Models

struct TomTomRouteResponse: Codable {
    let routes: [TomTomRoute]
}

struct TomTomRoute: Codable {
    let summary: TomTomRouteSummary
    let legs: [TomTomLeg]
}

struct TomTomRouteSummary: Codable {
    let lengthInMeters: Int
    let travelTimeInSeconds: Int
    let trafficDelayInSeconds: Int?
    let departureTime: String?
    let arrivalTime: String?
}

struct TomTomLeg: Codable {
    let summary: TomTomRouteSummary
    let points: [TomTomPoint]
}

struct TomTomPoint: Codable {
    let latitude: Double
    let longitude: Double
}

struct TomTomGuidanceInstruction: Codable {
    let maneuver: String?
    let instruction: String
    let distance: Int
    let routeOffsetInMeters: Int?
}

// MARK: - Routing Service

class TomTomRoutingService {

    private let apiKey: String
    private let baseURL = "https://api.tomtom.com/routing/1/calculateRoute"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        truckParams: TruckParameters,
        completion: @escaping (Result<TomTomRouteResponse, Error>) -> Void
    ) {
        // Build coordinates string
        let coordinates = "\(origin.latitude),\(origin.longitude):\(destination.latitude),\(destination.longitude)"

        // Build URL
        var components = URLComponents(string: "\(baseURL)/\(coordinates)/json")

        // Base parameters
        var queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "travelMode", value: "truck"),
            URLQueryItem(name: "traffic", value: "true"),
            URLQueryItem(name: "routeType", value: "fastest"),
            URLQueryItem(name: "instructionsType", value: "text")
        ]

        // Add truck parameters
        let truckQueryParams = truckParams.toQueryParameters()
        for (key, value) in truckQueryParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(.failure(NSError(domain: "TomTomRouting", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        print("🚛 TomTom API Request: \(url.absoluteString)")

        // Make request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomRouting", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            // Debug: Print response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🚛 TomTom API Response: \(jsonString.prefix(500))...")
            }

            do {
                let decoder = JSONDecoder()
                let routeResponse = try decoder.decode(TomTomRouteResponse.self, from: data)
                completion(.success(routeResponse))
            } catch {
                print("❌ TomTom decode error: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }
}

// MARK: - Route Conversion

extension TomTomRoute {
    func toCoordinates() -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []

        for leg in legs {
            for point in leg.points {
                coordinates.append(CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
            }
        }

        return coordinates
    }

    var distance: Double {
        return Double(summary.lengthInMeters)
    }

    var travelTime: TimeInterval {
        return TimeInterval(summary.travelTimeInSeconds)
    }
}
