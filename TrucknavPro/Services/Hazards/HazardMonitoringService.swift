//
//  HazardMonitoringService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation
import MapboxDirections

class HazardMonitoringService {

    private let tomTomApiKey: String
    private let osmService: OpenStreetMapService
    private var monitoringTimer: Timer?
    private var lastCheckedLocation: CLLocation?
    private let checkDistanceThreshold: Double = 100 // Check every 100 meters
    private var cachedRestrictions: [OSMRestriction] = []
    private var lastOSMQueryTime: Date?

    var onHazardDetected: ((HazardAlert) -> Void)?

    init(tomTomApiKey: String) {
        self.tomTomApiKey = tomTomApiKey
        self.osmService = OpenStreetMapService()
    }

    // MARK: - Public Methods

    func startMonitoring(currentLocation: CLLocation, route: [CLLocationCoordinate2D]) {
        // Check if hazard warnings are enabled
        guard TruckSettings.enableHazardWarnings else {
            print("🚨 Hazard monitoring disabled by user settings")
            return
        }

        print("🚨 Hazard monitoring started")

        // Query OSM for restrictions along the entire route
        osmService.queryRestrictions(alongRoute: route) { [weak self] restrictions in
            guard let self = self else { return }
            self.cachedRestrictions = restrictions
            self.lastOSMQueryTime = Date()
            print("🗺️ Cached \(restrictions.count) restrictions from OSM")

            // Check immediately with cached restrictions
            self.checkForHazards(at: currentLocation, alongRoute: route)
        }

        // Set up timer for continuous monitoring (every 5 seconds)
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForHazards(at: currentLocation, alongRoute: route)
        }
    }

    func stopMonitoring() {
        print("🚨 Hazard monitoring stopped")
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        lastCheckedLocation = nil
    }

    func updateLocation(_ location: CLLocation, route: [CLLocationCoordinate2D]) {
        // Only check if moved significantly
        if let lastLocation = lastCheckedLocation {
            let distance = location.distance(from: lastLocation)
            if distance < checkDistanceThreshold {
                return
            }
        }

        lastCheckedLocation = location
        checkForHazards(at: location, alongRoute: route)
    }

    // MARK: - Private Methods

    private func checkForHazards(at location: CLLocation, alongRoute route: [CLLocationCoordinate2D]) {
        // Check if hazard warnings are enabled
        guard TruckSettings.enableHazardWarnings else {
            return
        }

        // Get upcoming route segment (next 2km/1.2 miles)
        let upcomingSegment = getUpcomingRouteSegment(from: location.coordinate, route: route, lookAheadDistance: 2000)

        guard !upcomingSegment.isEmpty else { return }

        // Check for OSM restrictions
        checkOSMRestrictions(for: upcomingSegment, from: location)

        // Check for geometric hazards (sharp turns)
        checkRouteGeometry(segment: upcomingSegment, from: location)
    }

    private func getUpcomingRouteSegment(from location: CLLocationCoordinate2D, route: [CLLocationCoordinate2D], lookAheadDistance: Double) -> [CLLocationCoordinate2D] {
        var segment: [CLLocationCoordinate2D] = []
        var accumulatedDistance: Double = 0

        // Find closest point on route to current location
        var closestIndex = 0
        var minDistance = Double.infinity

        for (index, coord) in route.enumerated() {
            let distance = location.distance(to: coord)
            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }

        // Collect points ahead within lookAheadDistance
        for i in closestIndex..<route.count {
            segment.append(route[i])

            if i < route.count - 1 {
                let dist = route[i].distance(to: route[i + 1])
                accumulatedDistance += dist

                if accumulatedDistance >= lookAheadDistance {
                    break
                }
            }
        }

        return segment
    }

    private func checkOSMRestrictions(for segment: [CLLocationCoordinate2D], from location: CLLocation) {
        // Check cached OSM restrictions against upcoming route segment
        guard !cachedRestrictions.isEmpty else { return }

        // Get truck dimensions
        let truckHeight = TruckSettings.height
        let truckWeight = TruckSettings.weight
        let truckWidth = TruckSettings.width
        let truckLength = TruckSettings.length

        // Check each restriction
        for restriction in cachedRestrictions {
            // Find if restriction is in upcoming segment
            guard let closestPoint = findClosestPoint(to: restriction.coordinate, in: segment) else { continue }

            let distanceToRestriction = location.coordinate.distance(to: closestPoint)

            // Only alert for restrictions within configured warning distance
            let warningDistance = TruckSettings.warningDistance
            guard distanceToRestriction < warningDistance && distanceToRestriction > 50 else { continue }

            // Check if this restriction applies to our truck
            var shouldAlert = false

            switch restriction.type {
            case .maxheight:
                // Convert both to meters for comparison
                let restrictionMeters = restriction.unit == "m" ? restriction.value : restriction.value / 3.28084
                if truckHeight >= restrictionMeters - 0.05 { // 5cm margin
                    shouldAlert = true
                }

            case .maxweight:
                // Convert to metric tons for comparison
                let restrictionTons = restriction.unit == "t" ? restriction.value : restriction.value / 2204.62
                if truckWeight >= restrictionTons * 1000 - 100 { // 100kg margin
                    shouldAlert = true
                }

            case .maxwidth:
                // Convert both to meters for comparison
                let restrictionMeters = restriction.unit == "m" ? restriction.value : restriction.value / 3.28084
                if truckWidth >= restrictionMeters - 0.05 { // 5cm margin
                    shouldAlert = true
                }

            case .maxlength:
                // Convert both to meters for comparison
                let restrictionMeters = restriction.unit == "m" ? restriction.value : restriction.value / 3.28084
                if truckLength >= restrictionMeters - 0.1 { // 10cm margin
                    shouldAlert = true
                }
            }

            if shouldAlert {
                let alert = HazardAlert(
                    type: restriction.toHazardType(),
                    distanceInMeters: distanceToRestriction,
                    location: restriction.roadName
                )
                onHazardDetected?(alert)
                print("🚨 OSM Restriction: \(restriction.type.rawValue) at \(String(format: "%.0f", distanceToRestriction))m - \(restriction.roadName ?? "unnamed road")")
                return // Only report one hazard at a time
            }
        }
    }

    private func findClosestPoint(to coordinate: CLLocationCoordinate2D, in segment: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !segment.isEmpty else { return nil }

        var closestPoint = segment[0]
        var minDistance = coordinate.distance(to: segment[0])

        for point in segment {
            let distance = coordinate.distance(to: point)
            if distance < minDistance {
                minDistance = distance
                closestPoint = point
            }
        }

        // Only return if within 200m of route
        return minDistance < 200 ? closestPoint : nil
    }

    private func checkRouteGeometry(segment: [CLLocationCoordinate2D], from location: CLLocation) {
        guard segment.count >= 3 else { return }

        // Check for sharp turns (simplified)
        for i in 1..<min(segment.count - 1, 10) { // Check next 10 points
            let bearing1 = segment[i - 1].bearing(to: segment[i])
            let bearing2 = segment[i].bearing(to: segment[i + 1])
            let turnAngle = abs(bearing2 - bearing1)

            // Normalize angle to 0-180
            let normalizedAngle = min(turnAngle, 360 - turnAngle)

            if normalizedAngle > 90 { // Sharp turn detected
                let distanceToTurn = location.coordinate.distance(to: segment[i])

                if distanceToTurn < 1000 && distanceToTurn > 50 { // Within 1km but not immediate
                    let alert = HazardAlert(
                        type: .sharpTurn,
                        distanceInMeters: distanceToTurn,
                        location: nil
                    )
                    onHazardDetected?(alert)
                    print("🚨 Sharp turn detected at \(distanceToTurn)m ahead")
                    return // Only report one hazard at a time
                }
            }
        }

        // In production, you would:
        // 1. Query TomTom Traffic API for restrictions along segment
        // 2. Parse bridge clearances, weight limits, width restrictions
        // 3. Compare against truck dimensions from TruckSettings
        // 4. Generate appropriate HazardAlert
    }

    // MARK: - TomTom API Integration (Placeholder)

    private func queryTomTomRestrictions(coordinates: [CLLocationCoordinate2D], completion: @escaping ([TomTomRestriction]) -> Void) {
        // This would make actual API calls to TomTom Traffic API
        // For now, returning empty array
        // Real implementation would use:
        // https://api.tomtom.com/traffic/services/4/flowSegmentData/...
        completion([])
    }
}

// MARK: - Supporting Models

struct TomTomRestriction {
    let type: RestrictionType
    let value: Double
    let unit: String
    let coordinate: CLLocationCoordinate2D

    enum RestrictionType {
        case height
        case weight
        case width
        case length
    }

    func toHazardType() -> HazardType {
        switch type {
        case .height:
            return .lowBridge(clearance: value, unit: unit)
        case .weight:
            return .weightLimit(limit: value, unit: unit)
        case .width:
            return .widthRestriction(width: value, unit: unit)
        case .length:
            return .lengthRestriction(length: value, unit: unit)
        }
    }
}

// MARK: - Coordinate Extensions

extension CLLocationCoordinate2D {
    func bearing(to coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let dLon = (coordinate.longitude - self.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
