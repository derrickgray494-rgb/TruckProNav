//
//  TomTomTrafficService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation
import MapboxMaps

class TomTomTrafficService {

    private let apiKey: String
    private let baseFlowURL = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json"
    private let baseIncidentURL = "https://api.tomtom.com/traffic/services/5/incidentDetails"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Traffic Flow

    struct TrafficFlow {
        let freeFlowSpeed: Int
        let currentSpeed: Int
        let congestion: Int  // 0=flow, 1=slow, 2=congestion, 3=heavy
        let confidence: Double
        let roadClosure: Bool
    }

    func getTrafficFlow(
        at coordinate: CLLocationCoordinate2D,
        completion: @escaping (Result<TrafficFlow, Error>) -> Void
    ) {
        let urlString = "\(baseFlowURL)?key=\(apiKey)&point=\(coordinate.latitude),\(coordinate.longitude)"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TomTomTraffic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomTraffic", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                struct Response: Codable {
                    struct FlowData: Codable {
                        let freeFlowSpeed: Int?
                        let currentSpeed: Int?
                        let confidence: Double?
                        let roadClosure: Bool?

                        // Congestion is calculated, not directly provided
                        var congestion: Int {
                            guard let free = freeFlowSpeed, let current = currentSpeed else { return 0 }
                            let ratio = Double(current) / Double(free)
                            if ratio >= 0.75 { return 0 } // Free flow
                            if ratio >= 0.5 { return 1 }  // Slow
                            if ratio >= 0.25 { return 2 } // Congestion
                            return 3 // Heavy congestion
                        }
                    }
                    let flowSegmentData: FlowData
                }

                let response = try JSONDecoder().decode(Response.self, from: data)
                let flow = TrafficFlow(
                    freeFlowSpeed: response.flowSegmentData.freeFlowSpeed ?? 50,
                    currentSpeed: response.flowSegmentData.currentSpeed ?? 50,
                    congestion: response.flowSegmentData.congestion,
                    confidence: response.flowSegmentData.confidence ?? 0.5,
                    roadClosure: response.flowSegmentData.roadClosure ?? false
                )
                completion(.success(flow))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Traffic Incidents

    struct TrafficIncident {
        let id: String
        let type: Int  // 1=accident, 2=roadwork, 3=closure, etc.
        let severity: String  // Severe, High, Medium, Minor
        let coordinate: CLLocationCoordinate2D
        let description: String
    }

    func getTrafficIncidents(
        in boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double),
        completion: @escaping (Result<[TrafficIncident], Error>) -> Void
    ) {
        let bbox = "\(boundingBox.minLat),\(boundingBox.minLon),\(boundingBox.maxLat),\(boundingBox.maxLon)"
        let urlString = "\(baseIncidentURL)?key=\(apiKey)&bbox=\(bbox)&timeValidityFilter=present&categoryFilter=1,2,3,8"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TomTomTraffic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TomTomTraffic", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                struct Response: Codable {
                    struct Incident: Codable {
                        struct Properties: Codable {
                            let id: String
                            let iconCategory: Int
                            let magnitudeOfDelay: Int?
                            let events: [Event]?

                            struct Event: Codable {
                                let description: String?
                                let code: Int
                            }
                        }
                        struct Geometry: Codable {
                            let coordinates: [[Double]]?
                            let type: String
                        }

                        let properties: Properties
                        let geometry: Geometry
                    }
                    let features: [Incident]?
                }

                let decoder = JSONDecoder()
                let response = try decoder.decode(Response.self, from: data)

                let incidents = (response.features ?? []).compactMap { incident -> TrafficIncident? in
                    guard let coords = incident.geometry.coordinates?.first else { return nil }

                    // Extract severity based on magnitude of delay
                    let severity: String
                    if let magnitude = incident.properties.magnitudeOfDelay {
                        switch magnitude {
                        case 0: severity = "Minor"
                        case 1: severity = "Medium"
                        case 2: severity = "High"
                        case 3...Int.max: severity = "Severe"
                        default: severity = "Unknown"
                        }
                    } else {
                        severity = "Medium"
                    }

                    let description = incident.properties.events?.first?.description ?? "Traffic incident"

                    return TrafficIncident(
                        id: incident.properties.id,
                        type: incident.properties.iconCategory,
                        severity: severity,
                        coordinate: CLLocationCoordinate2D(
                            latitude: coords[1],  // TomTom uses [lon, lat] format
                            longitude: coords[0]
                        ),
                        description: description
                    )
                }

                completion(.success(incidents))
            } catch {
                print("❌ TomTom Traffic decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}
