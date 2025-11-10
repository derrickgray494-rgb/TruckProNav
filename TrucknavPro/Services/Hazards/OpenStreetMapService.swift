//
//  OpenStreetMapService.swift
//  TruckNavPro
//
//  OpenStreetMap Overpass API integration for truck restrictions
//

import Foundation
import CoreLocation

// MARK: - OSM Restriction Models

struct OSMRestriction {
    let coordinate: CLLocationCoordinate2D
    let type: RestrictionType
    let value: Double
    let unit: String
    let roadName: String?

    enum RestrictionType: String {
        case maxheight
        case maxweight
        case maxwidth
        case maxlength
    }

    func toHazardType() -> HazardType {
        switch type {
        case .maxheight:
            return .lowBridge(clearance: value, unit: unit)
        case .maxweight:
            return .weightLimit(limit: value, unit: unit)
        case .maxwidth:
            return .widthRestriction(width: value, unit: unit)
        case .maxlength:
            return .lengthRestriction(length: value, unit: unit)
        }
    }
}

// MARK: - OSM API Response Models

struct OSMResponse: Codable {
    let elements: [OSMElement]
}

struct OSMElement: Codable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
    let nodes: [Int64]?
    let geometry: [OSMNode]?

    struct OSMNode: Codable {
        let lat: Double
        let lon: Double
    }
}

// MARK: - OpenStreetMap Service

class OpenStreetMapService {

    private let baseURL = "https://overpass-api.de/api/interpreter"
    private var restrictionCache: [String: [OSMRestriction]] = [:]
    private let cacheTimeout: TimeInterval = 3600 // 1 hour
    private var lastCacheTime: Date?

    // MARK: - Public Methods

    /// Query restrictions along a route
    func queryRestrictions(alongRoute coordinates: [CLLocationCoordinate2D], completion: @escaping ([OSMRestriction]) -> Void) {
        guard !coordinates.isEmpty else {
            completion([])
            return
        }

        // Sample coordinates every 500m to avoid too many queries
        let sampledCoordinates = sampleCoordinates(coordinates, interval: 500)

        print("🗺️ OSM: Querying restrictions for \(sampledCoordinates.count) sample points")

        // Build Overpass QL query
        let query = buildOverpassQuery(for: sampledCoordinates)

        // Make API request
        executeOverpassQuery(query) { [weak self] result in
            switch result {
            case .success(let response):
                let restrictions = self?.parseRestrictions(from: response) ?? []
                print("🗺️ OSM: Found \(restrictions.count) restrictions")
                completion(restrictions)

            case .failure(let error):
                print("⚠️ OSM: Query failed - \(error.localizedDescription)")
                completion([])
            }
        }
    }

    /// Query restrictions near a single point
    func queryRestrictionsNearby(coordinate: CLLocationCoordinate2D, radius: Double = 1000, completion: @escaping ([OSMRestriction]) -> Void) {
        let query = buildOverpassQuery(for: [coordinate], radius: Int(radius))

        executeOverpassQuery(query) { [weak self] result in
            switch result {
            case .success(let response):
                let restrictions = self?.parseRestrictions(from: response) ?? []
                completion(restrictions)

            case .failure(let error):
                print("⚠️ OSM: Nearby query failed - \(error.localizedDescription)")
                completion([])
            }
        }
    }

    // MARK: - Private Methods

    private func sampleCoordinates(_ coordinates: [CLLocationCoordinate2D], interval: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1 else { return coordinates }

        var sampled: [CLLocationCoordinate2D] = [coordinates.first!]
        var accumulatedDistance: Double = 0

        for i in 1..<coordinates.count {
            let distance = coordinates[i-1].distance(to: coordinates[i])
            accumulatedDistance += distance

            if accumulatedDistance >= interval {
                sampled.append(coordinates[i])
                accumulatedDistance = 0
            }
        }

        // Always include last coordinate
        if let last = coordinates.last, last.latitude != sampled.last?.latitude {
            sampled.append(last)
        }

        return sampled
    }

    private func buildOverpassQuery(for coordinates: [CLLocationCoordinate2D], radius: Int = 100) -> String {
        var queryParts: [String] = []

        for coord in coordinates {
            let lat = coord.latitude
            let lon = coord.longitude

            // Query for ways with truck restrictions near this coordinate
            queryParts.append("way(around:\(radius),\(lat),\(lon))[\"maxheight\"];")
            queryParts.append("way(around:\(radius),\(lat),\(lon))[\"maxweight\"];")
            queryParts.append("way(around:\(radius),\(lat),\(lon))[\"maxwidth\"];")
            queryParts.append("way(around:\(radius),\(lat),\(lon))[\"maxlength\"];")
        }

        let query = """
        [out:json][timeout:25];
        (
        \(queryParts.joined(separator: "\n"))
        );
        out body geom;
        """

        return query
    }

    private func executeOverpassQuery(_ query: String, completion: @escaping (Result<OSMResponse, Error>) -> Void) {
        guard let url = URL(string: baseURL) else {
            completion(.failure(NSError(domain: "OSM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = query.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "OSM", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let osmResponse = try decoder.decode(OSMResponse.self, from: data)
                completion(.success(osmResponse))
            } catch {
                print("⚠️ OSM: Decode error - \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    private func parseRestrictions(from response: OSMResponse) -> [OSMRestriction] {
        var restrictions: [OSMRestriction] = []

        for element in response.elements {
            guard let tags = element.tags else { continue }

            // Get coordinate (use first geometry point if available, or element center)
            var coordinate: CLLocationCoordinate2D?
            if let geometry = element.geometry, let first = geometry.first {
                coordinate = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
            } else if let lat = element.lat, let lon = element.lon {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }

            guard let coord = coordinate else { continue }

            let roadName = tags["name"]

            // Parse maxheight
            if let maxheight = tags["maxheight"] {
                if let restriction = parseHeightRestriction(maxheight, coordinate: coord, roadName: roadName) {
                    restrictions.append(restriction)
                }
            }

            // Parse maxweight
            if let maxweight = tags["maxweight"] {
                if let restriction = parseWeightRestriction(maxweight, coordinate: coord, roadName: roadName) {
                    restrictions.append(restriction)
                }
            }

            // Parse maxwidth
            if let maxwidth = tags["maxwidth"] {
                if let restriction = parseWidthRestriction(maxwidth, coordinate: coord, roadName: roadName) {
                    restrictions.append(restriction)
                }
            }

            // Parse maxlength
            if let maxlength = tags["maxlength"] {
                if let restriction = parseLengthRestriction(maxlength, coordinate: coord, roadName: roadName) {
                    restrictions.append(restriction)
                }
            }
        }

        return restrictions
    }

    // MARK: - Value Parsing

    private func parseHeightRestriction(_ value: String, coordinate: CLLocationCoordinate2D, roadName: String?) -> OSMRestriction? {
        // OSM formats: "3.5", "3.5 m", "11'6\"", "3.5m"
        let cleaned = value.trimmingCharacters(in: .whitespaces).lowercased()

        // Check for feet/inches format: 11'6"
        if cleaned.contains("'") {
            let parts = cleaned.components(separatedBy: "'")
            if let feet = Double(parts[0].trimmingCharacters(in: .whitespaces)) {
                var inches = 0.0
                if parts.count > 1 {
                    let inchPart = parts[1].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
                    inches = Double(inchPart) ?? 0
                }
                let totalFeet = feet + (inches / 12.0)
                return OSMRestriction(coordinate: coordinate, type: .maxheight, value: totalFeet, unit: "ft", roadName: roadName)
            }
        }

        // Check for meters: "3.5", "3.5 m", "3.5m"
        let numeric = cleaned.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        if let meters = Double(numeric) {
            return OSMRestriction(coordinate: coordinate, type: .maxheight, value: meters, unit: "m", roadName: roadName)
        }

        return nil
    }

    private func parseWeightRestriction(_ value: String, coordinate: CLLocationCoordinate2D, roadName: String?) -> OSMRestriction? {
        // OSM formats: "10", "10 t", "10t", "22000 lbs"
        let cleaned = value.trimmingCharacters(in: .whitespaces).lowercased()

        let numeric = cleaned.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        guard let weight = Double(numeric) else { return nil }

        // Determine unit
        let unit: String
        if cleaned.contains("lb") {
            unit = "lbs"
        } else {
            unit = "t" // Default to metric tons
        }

        return OSMRestriction(coordinate: coordinate, type: .maxweight, value: weight, unit: unit, roadName: roadName)
    }

    private func parseWidthRestriction(_ value: String, coordinate: CLLocationCoordinate2D, roadName: String?) -> OSMRestriction? {
        // OSM formats: "2.5", "2.5 m", "8'"
        let cleaned = value.trimmingCharacters(in: .whitespaces).lowercased()

        if cleaned.contains("'") {
            let numeric = cleaned.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if let feet = Double(numeric) {
                return OSMRestriction(coordinate: coordinate, type: .maxwidth, value: feet, unit: "ft", roadName: roadName)
            }
        }

        let numeric = cleaned.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        if let meters = Double(numeric) {
            return OSMRestriction(coordinate: coordinate, type: .maxwidth, value: meters, unit: "m", roadName: roadName)
        }

        return nil
    }

    private func parseLengthRestriction(_ value: String, coordinate: CLLocationCoordinate2D, roadName: String?) -> OSMRestriction? {
        // OSM formats: "12", "12 m", "40'"
        let cleaned = value.trimmingCharacters(in: .whitespaces).lowercased()

        if cleaned.contains("'") {
            let numeric = cleaned.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if let feet = Double(numeric) {
                return OSMRestriction(coordinate: coordinate, type: .maxlength, value: feet, unit: "ft", roadName: roadName)
            }
        }

        let numeric = cleaned.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        if let meters = Double(numeric) {
            return OSMRestriction(coordinate: coordinate, type: .maxlength, value: meters, unit: "m", roadName: roadName)
        }

        return nil
    }
}
