//
//  NavigationViewController.swift
//  TruckNavPro
//

import UIKit
import MapboxMaps
import MapboxDirections
import CoreLocation
import Combine

class NavigationViewController: UIViewController {
    
    private var mapView: MapView!
    private let locationManager = CLLocationManager()
    private var cancelables = Set<AnyCancelable>()
    private var lastBearing: CLLocationDirection = 0
    
    private lazy var testButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📍 Set Test Destination", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(setTestDestination), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        setupMapView()
        setupTestButton()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setupMapView() {
        let mapInitOptions = MapInitOptions(styleURI: .streets)
        mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        
        mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            self?.configurePuck()
            self?.configureNavigationCamera()
            self?.enable3DBuildings()
            print("✅ Free-drive navigation active")
        }.store(in: &cancelables)
    }
    
    private func configurePuck() {
        var puckConfig = Puck2DConfiguration()
        puckConfig.showsAccuracyRing = false
        puckConfig.pulsing = .default
        mapView.location.options.puckType = .puck2D(puckConfig)
        mapView.location.options.puckBearingEnabled = true
    }
    
    private func configureNavigationCamera() {
        let pitch: CGFloat = 60
        let zoom: CGFloat = 17
        
        mapView.location.onLocationChange.observe { [weak self] locations in
            guard let self = self, let location = locations.last else { return }
            
            var bearing = self.lastBearing
            if let clLocation = location as? CLLocation, clLocation.course >= 0 {
                bearing = clLocation.course
                self.lastBearing = bearing
            }
            
            let cameraOptions = CameraOptions(
                center: location.coordinate,
                padding: UIEdgeInsets(top: 0, left: 0, bottom: self.view.bounds.height * 0.4, right: 0),
                zoom: zoom,
                bearing: bearing,
                pitch: pitch
            )
            
            self.mapView.camera.ease(to: cameraOptions, duration: 1.0)
        }.store(in: &self.cancelables)
    }
    
    private func enable3DBuildings() {
        do {
            var layer = FillExtrusionLayer(id: "3d-buildings", source: "composite")
            layer.sourceLayer = "building"
            layer.minZoom = 15
            layer.fillExtrusionHeight = .expression(Exp(.get) { "height" })
            layer.fillExtrusionBase = .expression(Exp(.get) { "min_height" })
            layer.fillExtrusionColor = .constant(StyleColor(.lightGray))
            layer.fillExtrusionOpacity = .constant(0.6)
            
            try mapView.mapboxMap.addLayer(layer)
            print("✅ 3D buildings enabled")
        } catch {
            print("⚠️ 3D buildings error: \(error)")
        }
    }
    
    private func setupTestButton() {
        view.addSubview(testButton)
        
        NSLayoutConstraint.activate([
            testButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            testButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testButton.widthAnchor.constraint(equalToConstant: 250),
            testButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func setTestDestination() {
        print("🔥 BUTTON TAPPED!")
        
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location")
            
            let alert = UIAlertController(
                title: "No Location",
                message: "Waiting for location...",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        print("✅ User location: \(userLocation)")
        
        let testDestination = CLLocationCoordinate2D(
            latitude: userLocation.latitude + 0.05,
            longitude: userLocation.longitude
        )
        
        calculateRoute(to: testDestination)
    }
    
    private func calculateRoute(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location available")
            return
        }
        
        print("🗺️ Calculating route from \(userLocation) to \(destination)")
        
        let origin = Waypoint(coordinate: userLocation)
        let destinationWaypoint = Waypoint(coordinate: destination)
        
        let options = RouteOptions(waypoints: [origin, destinationWaypoint])
        options.profileIdentifier = .automobileAvoidingTraffic
        options.includesSteps = true
        
        guard let accessToken = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String else {
            print("⚠️ No Mapbox access token found")
            return
        }
        
        let directions = Directions(credentials: Credentials(accessToken: accessToken))
        
        directions.calculate(options) { [weak self] (result: Result<RouteResponse, DirectionsError>) in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                guard let route = response.routes?.first else {
                    print("⚠️ No route found")
                    return
                }
                
                print("✅ Route calculated: \(route.distance) meters, \(route.expectedTravelTime) seconds")
                
                DispatchQueue.main.async {
                    self.drawRoute(route)
                }
                
            case .failure(let error):
                print("❌ Route calculation failed: \(error)")
                
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Route Error",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func drawRoute(_ route: Route) {
        print("📍 Route has \(route.shape?.coordinates.count ?? 0) coordinates")
        
        try? mapView.mapboxMap.removeLayer(withId: "route-layer")
        try? mapView.mapboxMap.removeSource(withId: "route-source")
        
        if let coordinates = route.shape?.coordinates {
            var feature = Feature(geometry: .lineString(LineString(coordinates)))
            feature.identifier = .string("route")
            
            var source = GeoJSONSource(id: "route-source")
            source.data = .feature(feature)
            
            try? mapView.mapboxMap.addSource(source)
            
            var routeLayer = LineLayer(id: "route-layer", source: "route-source")
            routeLayer.lineColor = .constant(StyleColor(.systemBlue))
            routeLayer.lineWidth = .constant(5)
            routeLayer.lineCap = .constant(.round)
            routeLayer.lineJoin = .constant(.round)
            
            try? mapView.mapboxMap.addLayer(routeLayer)
            
            print("✅ Route line drawn on map")
        }
        
        let alert = UIAlertController(
            title: "✅ Route Found!",
            message: "Distance: \(Int(route.distance)) meters\nTime: \(Int(route.expectedTravelTime / 60)) minutes",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension NavigationViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            lastBearing = newHeading.trueHeading
        }
    }
}
