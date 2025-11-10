//
//  MapMatchingService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation
import MapboxDirections

/// Service to convert TomTom route coordinates to Mapbox NavigationRoutes using Map Matching API
class MapMatchingService {

    private let accessToken: String
    private let baseURL = "https://api.mapbox.com/matching/v5/mapbox"

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    /// Convert TomTom route to Mapbox NavigationRoutes using Map Matching API
    /// - Parameters:
    ///   - tomtomRoute: The TomTom route with truck-specific routing
    ///   - completion: Returns NavigationRoutes or error
    func matchRoute(
        from tomtomRoute: TomTomRoute,
        completion: @escaping (Result<MatchResponse, Error>) -> Void
    ) {
        let coordinates = tomtomRoute.toCoordinates()

        // Map Matching API has a limit of 100 coordinates
        // If more, we need to split or sample the route
        let sampledCoordinates = sampleCoordinates(coordinates, maxCount: 100)

        guard sampledCoordinates.count >= 2 else {
            completion(.failure(MapMatchingError.insufficientCoordinates))
            return
        }

        // Build URL with coordinates
        let coordinatesString = sampledCoordinates.map { coordinate in
            "\(coordinate.longitude),\(coordinate.latitude)"
        }.joined(separator: ";")

        // Use driving-traffic profile for real-time traffic
        let urlString = "\(baseURL)/driving-traffic/\(coordinatesString)"

        var components = URLComponents(string: urlString)

        // Add query parameters
        var queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "geometries", value: "polyline6"),
            URLQueryItem(name: "overview", value: "full"),
            URLQueryItem(name: "steps", value: "true"),
            URLQueryItem(name: "voice_instructions", value: "true"),
            URLQueryItem(name: "banner_instructions", value: "true"),
            URLQueryItem(name: "tidy", value: "true") // Clean up clusters
        ]

        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(.failure(MapMatchingError.invalidURL))
            return
        }

        print("🗺️ Map Matching API Request: \(url.absoluteString.prefix(150))...")

        // Make request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(MapMatchingError.noData))
                return
            }

            // Debug: Print response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🗺️ Map Matching API Response: \(jsonString.prefix(500))...")
            }

            do {
                let decoder = JSONDecoder()
                let matchResponse = try decoder.decode(MatchResponse.self, from: data)

                if let firstMatching = matchResponse.matchings.first {
                    print("✅ Map matched route: \(firstMatching.distance)m, \(firstMatching.duration)s")
                    completion(.success(matchResponse))
                } else {
                    completion(.failure(MapMatchingError.noMatchings))
                }
            } catch {
                print("❌ Map Matching decode error: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    /// Sample coordinates to fit within Map Matching API limit
    private func sampleCoordinates(_ coordinates: [CLLocationCoordinate2D], maxCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxCount else {
            return coordinates
        }

        // Keep first and last, sample evenly in between
        let step = Double(coordinates.count - 1) / Double(maxCount - 1)
        var sampled: [CLLocationCoordinate2D] = []

        for i in 0..<maxCount {
            let index = min(Int(Double(i) * step), coordinates.count - 1)
            sampled.append(coordinates[index])
        }

        return sampled
    }
}

// MARK: - Response Models

struct MatchResponse: Codable {
    let matchings: [Matching]
    let code: String
}

struct Matching: Codable {
    let distance: Double
    let duration: Double
    let geometry: String
    let legs: [MatchLeg]?
    let weight: Double?
    let weightName: String?
    let confidence: Double?
}

struct MatchLeg: Codable {
    let distance: Double
    let duration: Double
    let steps: [MatchStep]?
    let summary: String?
}

struct MatchStep: Codable {
    let distance: Double
    let duration: Double
    let geometry: String
    let name: String?
    let mode: String?
    let maneuver: MatchManeuver?
    let voiceInstructions: [VoiceInstruction]?
    let bannerInstructions: [BannerInstruction]?
}

struct MatchManeuver: Codable {
    let type: String
    let instruction: String
    let bearingBefore: Int?
    let bearingAfter: Int?
    let location: [Double]
    let modifier: String?
}

struct VoiceInstruction: Codable {
    let distanceAlongGeometry: Double
    let announcement: String
    let ssmlAnnouncement: String?
}

struct BannerInstruction: Codable {
    let distanceAlongGeometry: Double
    let primary: BannerContent
    let secondary: BannerContent?
}

struct BannerContent: Codable {
    let text: String
    let type: String?
    let modifier: String?
}

// MARK: - Errors

enum MapMatchingError: LocalizedError {
    case insufficientCoordinates
    case invalidURL
    case noData
    case noMatchings

    var errorDescription: String? {
        switch self {
        case .insufficientCoordinates:
            return "Need at least 2 coordinates for map matching"
        case .invalidURL:
            return "Invalid Map Matching API URL"
        case .noData:
            return "No data received from Map Matching API"
        case .noMatchings:
            return "No route matchings found"
        }
    }
}
