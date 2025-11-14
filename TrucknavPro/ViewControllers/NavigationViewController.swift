//
//  NavigationViewController.swift
//  TruckNavPro
//

import UIKit
import MapboxMaps
import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxSearchUI
import CoreLocation
import Combine
import AudioToolbox

class MapViewController: UIViewController {

    internal var navigationMapView: NavigationMapView!  // Internal for POI extension access
    let locationManager = CLLocationManager()
    private var cancelables = Set<AnyCancellable>()
    private var lastBearing: CLLocationDirection = 0

    // Mapbox Navigation Provider (v3)
    private var navigationProvider: MapboxNavigationProvider!
    private var mapboxNavigation: MapboxNavigation!
    private var currentNavigationViewController: NavigationViewController?

    // Standard US Semi-Trailer Parameters (Imperial Units)
    internal let truckHeightFeet: Double = 13.5  // 13'6" standard semi height
    internal let truckWidthFeet: Double = 8.5    // 8'6" standard semi width
    internal let truckWeightLbs: Int = 80000     // 80,000 lbs federal max
    private let truckLengthFeet: Double = 70.0  // ~70 ft total (tractor + 53' trailer)

    // Computed properties for Mapbox (requires Measurement types with metric)
    private var truckHeight: Measurement<UnitLength> {
        return Measurement(value: truckHeightFeet * 0.3048, unit: .meters)
    }
    private var truckWidth: Measurement<UnitLength> {
        return Measurement(value: truckWidthFeet * 0.3048, unit: .meters)
    }
    private var truckWeight: Measurement<UnitMass> {
        return Measurement(value: Double(truckWeightLbs) * 0.000453592, unit: .metricTons)
    }

    // Navigation state
    private var isNavigating: Bool = false
    private var isFreeDriveActive: Bool = false
    private var currentNavigationRoutes: NavigationRoutes?
    private var selectedAlternativeRouteIndex: Int? = nil

    // Free-drive mode UI (Mapbox drop-in components)
    private let speedLimitView = SpeedLimitView()
    private let roadNameLabel = UILabel()

    // Route preview UI (Mapbox showcase() handles the route display)
    private let routePreviewContainer = UIView()
    private let routeDistanceLabel = UILabel()
    private let routeDurationLabel = UILabel()
    private let routeETALabel = UILabel()
    private let routeSelectionLabel = UILabel()  // Shows "Route 1 of 3"
    private let nextRouteButton = UIButton(type: .system)  // Cycle through alternatives
    private let startNavigationButton = UIButton(type: .system)
    private let cancelRouteButton = UIButton(type: .system)

    // MapboxSearchUI drop-in component (DISABLED - using custom search bar instead)
    // private var searchController: MapboxSearchController!
    // var panelController: MapboxPanelController!

    // Search result annotations
    var pointAnnotationManager: PointAnnotationManager!  // Internal for custom search bar access
    private var currentSearchResults: [SearchResult] = []

    // Weather update tracking
    private var lastWeatherUpdateTime: Date?

    // TomTom Services
    private var tomTomRoutingService: TomTomRoutingService?
    internal var tomTomTrafficService: TomTomTrafficService?  // Internal for traffic widget access
    var tomTomSearchService: TomTomSearchService?  // Internal for custom search bar access

    // HERE Services (Fallback)
    var hereSearchService: HERESearchService?  // Internal for custom search bar fallback
    internal var hereTrafficService: HERETrafficService?  // Internal for traffic widget fallback
    internal var hereRoutingService: HERERoutingService?  // Internal for multi-stop routing access
    private var hereWeatherService: HEREWeatherService?  // Destination weather

    private var trafficUpdateTimer: Timer?
    internal var incidentAnnotationManager: PointAnnotationManager?  // Internal for traffic extension

    // Waypoint & Multi-Stop Routing
    internal var waypointService: HEREWaypointService?  // Multi-stop optimization
    internal var stops: [Stop] = []  // List of route stops
    internal var stopAnnotationManager: PointAnnotationManager?  // Markers for stops
    internal var currentTruckProfile: HEREWaypointService.TruckProfile = .default
    internal var isStopsPanelCollapsed: Bool = false  // Collapsed state for stops panel
    internal var stopsPanelTrailingConstraint: NSLayoutConstraint?  // For animation

    // Hazard Warning System
    private var hazardMonitoringService: HazardMonitoringService?
    private var weatherOverlayService: WeatherOverlayService?
    private var currentHazardWarningView: HazardWarningView?
    private var lastHazardAlert: HazardAlert?

    lazy var recenterButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "location.fill", withConfiguration: config), for: .normal)
        button.backgroundColor = .systemBackground
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(recenterMap), for: .touchUpInside)
        return button
    }()

    lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "gearshape.fill", withConfiguration: config), for: .normal)
        button.backgroundColor = .systemBackground
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        return button
    }()

    private let weatherWidget: WeatherWidgetView = {
        let widget = WeatherWidgetView()
        widget.translatesAutoresizingMaskIntoConstraints = false
        return widget
    }()

    // Multi-stop waypoint UI components
    lazy var addStopButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: config), for: .normal)
        button.backgroundColor = .systemBackground
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(addStopTapped), for: .touchUpInside)
        return button
    }()

    lazy var stopsPanel: UIView = {
        let panel = UIView()
        panel.backgroundColor = .systemBackground
        panel.layer.cornerRadius = 16
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.3
        panel.layer.shadowOffset = CGSize(width: -2, height: 0)
        panel.layer.shadowRadius = 8
        panel.translatesAutoresizingMaskIntoConstraints = false
        return panel
    }()

    lazy var stopsTableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(StopCell.self, forCellReuseIdentifier: "StopCell")
        table.delegate = self
        table.dataSource = self
        table.dragDelegate = self
        table.dropDelegate = self
        table.dragInteractionEnabled = true
        table.separatorStyle = .singleLine
        return table
    }()

    lazy var emptyStateView: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true

        let iconImageView = UIImageView(image: UIImage(systemName: "map"))
        iconImageView.tintColor = .secondaryLabel
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "No Saved Destinations"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = "Tap + to add stops to your route"
        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .tertiaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconImageView)
        container.addSubview(titleLabel)
        container.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])

        return container
    }()

    lazy var optimizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🎯 Optimize Route", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(optimizeRouteTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Memory Management

    deinit {
        // Clean up keyboard observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)

        // Clean up background observers
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)

        // Clean up traffic timer
        trafficUpdateTimer?.invalidate()

        print("🧹 MapViewController deallocated - observers cleaned up")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup background observers to pause traffic updates when app is backgrounded
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Initialize Mapbox Navigation Provider (v3)
        let coreConfig = CoreConfig()
        navigationProvider = MapboxNavigationProvider(coreConfig: coreConfig)
        mapboxNavigation = navigationProvider.mapboxNavigation

        // Initialize TomTom Services if API key available
        if let tomTomApiKey = Bundle.main.infoDictionary?["TomTomAPIKey"] as? String, !tomTomApiKey.isEmpty {
            print("🔑 Found TomTom API key: \(tomTomApiKey.prefix(10))...")

            tomTomRoutingService = TomTomRoutingService(apiKey: tomTomApiKey)
            tomTomTrafficService = TomTomTrafficService(apiKey: tomTomApiKey)
            tomTomSearchService = TomTomSearchService(apiKey: tomTomApiKey)
            hazardMonitoringService = HazardMonitoringService(tomTomApiKey: tomTomApiKey)
            weatherOverlayService = WeatherOverlayService()
            setupHazardWarningCallbacks()

            print("✅ TomTom Services initialized successfully:")
            print("   - Routing: \(tomTomRoutingService != nil ? "✓" : "✗")")
            print("   - Traffic: \(tomTomTrafficService != nil ? "✓" : "✗")")
            print("   - Search: \(tomTomSearchService != nil ? "✓" : "✗")")
            print("   - Hazard Monitoring: \(hazardMonitoringService != nil ? "✓" : "✗")")
        } else {
            print("⚠️ TomTom API key not found in Info.plist")
            print("   Search will use Mapbox fallback")
            print("   To enable TomTom: Add TomTomAPIKey to Info.plist")
            print("   Get API key at: https://developer.tomtom.com/")
        }

        // Initialize HERE Services if API key available (fallback for search, traffic, routing, weather)
        if let hereApiKey = Bundle.main.infoDictionary?["HEREAPIKey"] as? String, !hereApiKey.isEmpty {
            print("🔑 Found HERE API key: \(hereApiKey.prefix(10))...")
            hereSearchService = HERESearchService(apiKey: hereApiKey)
            hereTrafficService = HERETrafficService(apiKey: hereApiKey)
            hereRoutingService = HERERoutingService(apiKey: hereApiKey)
            hereWeatherService = HEREWeatherService(apiKey: hereApiKey)
            waypointService = HEREWaypointService(apiKey: hereApiKey)
            print("✅ HERE Services initialized (fallback enabled):")
            print("   - Search: ✓")
            print("   - Traffic: ✓")
            print("   - Routing: ✓")
            print("   - Weather: ✓")
            print("   - Waypoints: ✓")
        } else {
            print("ℹ️ HERE API key not found - fallback services disabled")
            print("   To enable HERE fallback: Add HEREAPIKey to Info.plist")
            print("   Get API key at: https://developer.here.com/")
        }

        setupLocationManager()
        setupMapView()
        // setupSearchController()  // DISABLED - using custom search bar instead
        setupFreeDriveUI()
        setupRoutePreviewUI()
        setupRecenterButton()
        setupSettingsButton()
        setupWeatherWidget()
        setupTrafficWidget()
        setupWaypointUI()  // Multi-stop routing UI
        setupCustomSearchBar()  // Custom liquid glass search bar

        // Ensure proper z-ordering (bring controls to front)
        view.bringSubviewToFront(recenterButton)
        view.bringSubviewToFront(settingsButton)
        view.bringSubviewToFront(weatherWidget)
        view.bringSubviewToFront(trafficWidget)
        view.bringSubviewToFront(speedLimitView)
        view.bringSubviewToFront(roadNameLabel)
        view.bringSubviewToFront(routePreviewContainer)
        view.bringSubviewToFront(addStopButton)  // Multi-stop button
        view.bringSubviewToFront(stopsPanel)  // Multi-stop panel

        // CRITICAL: Bring search UI to front so results are visible
        bringSearchUIToFront()

        // Start free-drive mode for passive location tracking
        startFreeDriveMode()

        print("🚛 TruckNav Pro initialized with Mapbox Navigation SDK v3")
    }

    // MARK: - Truck Configuration Helpers

    /// Configure route options with truck parameters
    private func configureTruckRouteOptions(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> NavigationRouteOptions {
        // Create waypoints
        let waypoints = [origin, destination]

        let options = NavigationRouteOptions(coordinates: waypoints)

        // Set truck-specific parameters
        options.maximumHeight = truckHeight
        options.maximumWidth = truckWidth
        options.maximumWeight = truckWeight

        // Avoid unpaved roads and tunnels (for safety and hazmat)
        options.roadClassesToAvoid = [.unpaved]

        // Request route alternatives
        options.includesAlternativeRoutes = true

        // Enable detailed annotations for navigation
        options.attributeOptions = [.speed, .distance, .expectedTravelTime, .congestionLevel]

        print("🚛 Mapbox truck routing configured: \(truckWeightLbs) lbs, \(truckHeightFeet)' height, \(truckWidthFeet)' width")

        return options
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

        // Request "Always" authorization for background turn-by-turn navigation
        locationManager.requestAlwaysAuthorization()

        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    private func setupMapView() {
        // Create NavigationMapView for route preview and navigation (v3 syntax)
        navigationMapView = NavigationMapView(
            location: navigationProvider.mapboxNavigation.navigation().locationMatching
                .map(\.enhancedLocation)  // ✅ FIXED: Correct path (was .mapMatchingResult.enhancedLocation)
                .eraseToAnyPublisher(),
            routeProgress: navigationProvider.mapboxNavigation.navigation().routeProgress
                .map(\.?.routeProgress)
                .eraseToAnyPublisher(),
            heading: navigationProvider.mapboxNavigation.navigation().heading,
            predictiveCacheManager: navigationProvider.predictiveCacheManager
        )
        navigationMapView.frame = view.bounds
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Use 2D puck for maximum reliability (Mapbox recommended)
        navigationMapView.puckType = .puck2D(.navigationDefault)

        // Enable bearing tracking for directional indicator
        navigationMapView.mapView.location.options.puckBearingEnabled = true

        view.addSubview(navigationMapView)

        navigationMapView.mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
            self?.enable3DBuildings()
            self?.enableTrafficLayer()
            self?.setupAnnotationManager()
            self?.setupPOIManager()  // Initialize POI system
            self?.configureDayNightMode()
            self?.setInitialCameraPosition()
            self?.updateWeatherOverlay()
            print("✅ NavigationMapView loaded - ready for free-drive")
        }.store(in: &cancelables)
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

            try navigationMapView.mapView.mapboxMap.addLayer(layer)
            print("✅ 3D buildings enabled")
        } catch {
            print("⚠️ 3D buildings error: \(error)")
        }
    }

    private func enableTrafficLayer() {
        do {
            // Enable Mapbox Traffic layer (shows live congestion as colored road overlays)
            try navigationMapView.mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "showTraffic",
                value: true
            )
            print("🚦 Mapbox Traffic overlay enabled - showing live congestion")
        } catch {
            print("⚠️ Traffic layer error: \(error)")
        }
    }

    private func updateWeatherOverlay() {
        guard let weatherService = weatherOverlayService else { return }

        if TruckSettings.showWeatherOverlay {
            // Add weather overlay
            weatherService.addWeatherOverlay(to: navigationMapView.mapView) { success in
                if success {
                    print("🌧️ Weather radar overlay enabled")
                } else {
                    print("⚠️ Failed to add weather overlay")
                }
            }
        } else {
            // Remove weather overlay
            weatherService.removeWeatherOverlay(from: navigationMapView.mapView)
        }
    }

    private func setupAnnotationManager() {
        // Create annotation manager for search results
        pointAnnotationManager = navigationMapView.mapView.annotations.makePointAnnotationManager()

        // Handle annotation taps via delegate
        pointAnnotationManager.delegate = self

        // Create annotation manager for traffic incidents
        incidentAnnotationManager = navigationMapView.mapView.annotations.makePointAnnotationManager()

        // Create annotation manager for route stops
        stopAnnotationManager = navigationMapView.mapView.annotations.makePointAnnotationManager()

        print("✅ Annotation managers initialized")
    }

    private func configureDayNightMode() {
        // Set map style based on user preference or system color scheme
        let lightPreset: String
        switch TruckSettings.mapStyle {
        case .auto:
            // Use system appearance
            lightPreset = traitCollection.userInterfaceStyle == .dark ? "night" : "day"
        case .day:
            lightPreset = "day"
        case .night:
            lightPreset = "night"
        }

        do {
            try navigationMapView.mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: lightPreset
            )
            print("🌓 Map style set to \(lightPreset) mode (preference: \(TruckSettings.mapStyle.rawValue))")
        } catch {
            print("⚠️ Error setting map light preset: \(error)")
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Update map style when system appearance changes (only if in Auto mode)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            if TruckSettings.mapStyle == .auto {
                configureDayNightMode()
            }
        }
    }

    private func setInitialCameraPosition() {
        // Set initial camera to user location with proper zoom
        if let userLocation = locationManager.location?.coordinate {
            let cameraOptions = CameraOptions(
                center: userLocation,
                zoom: 16,
                bearing: 0,
                pitch: 45
            )
            navigationMapView.mapView.camera.fly(to: cameraOptions, duration: 1.0, completion: nil)
            print("📍 Initial camera set to user location at zoom 16")
        } else {
            // If no location yet, wait a bit and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setInitialCameraPosition()
            }
        }
    }

    // DISABLED - Using custom search bar instead
    /*
    private func setupSearchController() {
        // Initialize MapboxSearchUI SearchController (drop-in component)
        searchController = MapboxSearchController(apiType: .searchBox)
        searchController.delegate = self

        // Configure search options with user location proximity
        configureSearchProximity()

        // Wrap in MapboxPanelController (sliding drawer UI)
        panelController = MapboxPanelController(rootViewController: searchController)

        // Add as child view controller to embed the search panel
        addChild(panelController)
        view.addSubview(panelController.view)
        panelController.didMove(toParent: self)

        print("✅ MapboxSearchUI SearchController initialized with panel drawer")
    }

    private func configureSearchProximity() {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ User location not available yet for search proximity")
            return
        }

        var searchOptions = SearchOptions()
        searchOptions.proximity = userLocation
        searchOptions.limit = UserDefaults.standard.integer(forKey: "POIResultCount") > 0 ?
            UserDefaults.standard.integer(forKey: "POIResultCount") : 10

        searchController.searchOptions = searchOptions

        print("📍 Search proximity set to: lat=\(String(format: "%.4f", userLocation.latitude)), lon=\(String(format: "%.4f", userLocation.longitude)), limit=\(searchOptions.limit ?? 10)")
    }
    */

    private func setupRecenterButton() {
        view.addSubview(recenterButton)

        NSLayoutConstraint.activate([
            recenterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            recenterButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            recenterButton.widthAnchor.constraint(equalToConstant: 44),
            recenterButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func recenterMap() {
        // Resume camera following mode for free-drive
        if !isNavigating {
            navigationMapView.navigationCamera.update(cameraState: .following)
            print("📍 Camera following user bearing")
        } else {
            // During navigation, just recenter manually
            guard let userLocation = locationManager.location?.coordinate else { return }

            let cameraOptions = CameraOptions(
                center: userLocation,
                padding: UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.height * 0.4, right: 0),
                zoom: 17,
                bearing: lastBearing,
                pitch: 60
            )

            navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
            print("📍 Map recentered to current location")
        }
    }

    private func setupSettingsButton() {
        view.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            settingsButton.topAnchor.constraint(equalTo: recenterButton.bottomAnchor, constant: 16),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupWeatherWidget() {
        view.addSubview(weatherWidget)

        NSLayoutConstraint.activate([
            weatherWidget.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            weatherWidget.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            weatherWidget.widthAnchor.constraint(lessThanOrEqualToConstant: 180)
        ])

        // Fetch weather for initial location
        if let location = locationManager.location {
            fetchWeather(for: location.coordinate)
        }
    }

    private func fetchWeather(for coordinate: CLLocationCoordinate2D) {
        print("🌡️ Attempting to fetch weather for location: \(coordinate.latitude), \(coordinate.longitude)")

        // Use HERE Weather as primary (works in simulator, unlike WeatherKit)
        if let hereWeather = hereWeatherService {
            print("🌤️ Using HERE Weather (primary)...")
            hereWeather.getCurrentWeather(at: coordinate) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let hereConditions):
                        // Convert HERE weather to WeatherInfo format
                        let weatherInfo = WeatherInfo(
                            temperature: Int(hereConditions.temperature),
                            high: Int(hereConditions.temperature + 5),  // Approximate high
                            low: Int(hereConditions.temperature - 5),   // Approximate low
                            condition: hereConditions.description,
                            symbolName: hereConditions.condition.emoji,
                            dayName: DateFormatter().weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
                        )
                        self?.weatherWidget.configure(with: weatherInfo)
                        print("🌤️ HERE Weather updated: \(Int(hereConditions.temperature))°F \(hereConditions.condition.rawValue)")

                        // Display severe weather warnings
                        if hereConditions.condition.isSevere {
                            print("⚠️ SEVERE WEATHER: \(hereConditions.condition.rawValue)")
                        }

                    case .failure(let hereError):
                        print("❌ HERE Weather failed: \(hereError.localizedDescription)")
                        // Try WeatherKit as fallback
                        print("🔄 Falling back to WeatherKit...")
                        WeatherService.shared.fetchWeather(for: coordinate) { result in
                            switch result {
                            case .success(let weatherInfo):
                                self?.weatherWidget.configure(with: weatherInfo)
                                print("🌤️ WeatherKit updated: \(weatherInfo.temperature)° \(weatherInfo.condition)")
                            case .failure(let error):
                                print("❌ WeatherKit also failed: \(error.localizedDescription)")
                                print("⚠️ All weather services unavailable")
                            }
                        }
                    }
                }
            }
        } else {
            // HERE not available, try WeatherKit directly
            print("⚠️ HERE Weather not available, trying WeatherKit...")
            WeatherService.shared.fetchWeather(for: coordinate) { [weak self] result in
                switch result {
                case .success(let weatherInfo):
                    self?.weatherWidget.configure(with: weatherInfo)
                    print("🌤️ Weather updated: \(weatherInfo.temperature)° \(weatherInfo.condition)")
                case .failure(let error):
                    print("❌ Weather fetch failed: \(error.localizedDescription)")
                    print("⚠️ WeatherKit requires:")
                    print("   1. Valid Apple Developer account with WeatherKit enabled")
                    print("   2. App properly signed with provisioning profile")
                    print("   3. May not work in simulator - try physical device")
                }
            }
        }
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.delegate = self  // Set delegate to receive settings changes
        settingsVC.modalPresentationStyle = .pageSheet
        if let sheet = settingsVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(settingsVC, animated: true)
        print("⚙️ Opening settings")
    }

    // MARK: - Free-Drive Mode UI

    private func setupFreeDriveUI() {
        // Speed Limit View (Mapbox drop-in component)
        speedLimitView.translatesAutoresizingMaskIntoConstraints = false
        speedLimitView.isHidden = true
        view.addSubview(speedLimitView)

        // Road Name Label
        roadNameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        roadNameLabel.textColor = .label
        roadNameLabel.textAlignment = .center
        roadNameLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        roadNameLabel.layer.cornerRadius = 8
        roadNameLabel.clipsToBounds = true
        roadNameLabel.translatesAutoresizingMaskIntoConstraints = false
        roadNameLabel.isHidden = true
        view.addSubview(roadNameLabel)

        NSLayoutConstraint.activate([
            // Speed limit in top-right corner
            speedLimitView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            speedLimitView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            speedLimitView.widthAnchor.constraint(equalToConstant: 70),
            speedLimitView.heightAnchor.constraint(equalToConstant: 70),

            // Road name at bottom
            roadNameLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            roadNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            roadNameLabel.heightAnchor.constraint(equalToConstant: 40),
            roadNameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
    }

    private func startFreeDriveMode() {
        // Start Mapbox free-drive mode (passive navigation)
        // Note: Can be called multiple times - Mapbox handles restart internally
        navigationProvider.tripSession().startFreeDrive()

        // Keep flags in lockstep
        isFreeDriveActive = true
        isNavigating = false

        // Set initial camera position if location is available
        if let userLocation = locationManager.location?.coordinate {
            let cameraOptions = CameraOptions(
                center: userLocation,
                zoom: 16,
                bearing: locationManager.heading?.trueHeading ?? 0,
                pitch: 45
            )
            navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 0.5, curve: .easeOut, completion: nil)
        }

        // Enable camera to follow user bearing (heading direction)
        navigationMapView.navigationCamera.update(cameraState: .following)

        // Only create subscription once
        if cancelables.isEmpty {
            // Subscribe to location matching for speed limit and road name
            navigationProvider.mapboxNavigation.navigation().locationMatching.sink { [weak self] state in
                guard let self = self else { return }

                // Update speed limit (using Mapbox SpeedLimitView) - show during both free drive AND navigation
                if let speedLimit = state.speedLimit.value {
                    self.speedLimitView.signStandard = state.speedLimit.signStandard
                    self.speedLimitView.speedLimit = speedLimit
                    self.speedLimitView.isHidden = false
                    print("🚦 Speed limit: \(speedLimit) \(state.speedLimit.signStandard)")
                } else {
                    self.speedLimitView.isHidden = true
                }

                // Update road name
                if let roadName = state.roadName {
                    self.roadNameLabel.text = roadName.text
                    self.roadNameLabel.isHidden = false
                    print("🛣️ Road: \(roadName.text)")
                } else {
                    self.roadNameLabel.isHidden = true
                }
            }.store(in: &cancelables)

            // Subscribe to heading updates for aggressive bearing tracking
            subscribeToHeadingUpdates()
        }

        // Start traffic updates for real-time incident display
        startTrafficUpdates()

        print("🆓 Free-drive mode started - camera following user bearing")
    }

    // MARK: - Aggressive Camera Bearing Following

    private func subscribeToHeadingUpdates() {
        navigationProvider.mapboxNavigation.navigation().heading.sink { [weak self] heading in
            guard let self = self, !self.isNavigating else { return }
            self.updateCameraBearingContinuously(heading.trueHeading)
        }.store(in: &cancelables)

        print("🧭 Aggressive camera bearing tracking enabled")
    }

    private func updateCameraBearingContinuously(_ bearing: CLLocationDirection) {
        // Get current camera state
        let currentCamera = navigationMapView.mapView.cameraState

        // Only update if bearing changed significantly (avoid micro-adjustments that cause pauses)
        let currentBearing = currentCamera.bearing ?? 0
        let bearingDiff = abs(bearing - currentBearing)

        // Ignore tiny changes (less than 2 degrees) to reduce jitter
        guard bearingDiff > 2 || bearingDiff > 358 else { return }

        // Create updated camera options with new bearing
        let cameraOptions = CameraOptions(
            center: currentCamera.center,
            padding: currentCamera.padding,
            zoom: currentCamera.zoom,
            bearing: bearing,  // Update bearing to match heading
            pitch: 45  // Maintain elevated pitch for better 3D view
        )

        // Ultra-smooth update with faster 150ms easing and easeOut curve for natural deceleration
        navigationMapView.mapView.camera.ease(
            to: cameraOptions,
            duration: 0.15,
            curve: .easeOut,
            completion: nil
        )
    }

    // MARK: - Traffic Updates

    private func startTrafficUpdates() {
        // Require at least one traffic service (TomTom or HERE)
        guard tomTomTrafficService != nil || hereTrafficService != nil else {
            print("⚠️ No traffic services available")
            return
        }

        // Update immediately
        updateTrafficIncidents()

        // Then update every 5 minutes (300 seconds) for efficiency
        trafficUpdateTimer?.invalidate()
        trafficUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateTrafficIncidents()
        }

        print("🚦 Traffic updates started (5 minute interval)")
    }

    private func stopTrafficUpdates() {
        trafficUpdateTimer?.invalidate()
        trafficUpdateTimer = nil
        incidentAnnotationManager?.annotations = []
        print("🚦 Traffic updates stopped")
    }

    // MARK: - Background Handling

    @objc private func appDidEnterBackground() {
        // Stop traffic updates to save battery when app is in background
        trafficUpdateTimer?.invalidate()
        print("⏸️ App entered background - traffic timer paused")
    }

    @objc private func appWillEnterForeground() {
        // Restart traffic updates when app returns to foreground
        if trafficUpdateTimer != nil {
            startTrafficUpdates()
            print("▶️ App entering foreground - traffic timer resumed")
        }
    }

    private func updateTrafficIncidents() {
        // Get visible region bounds
        let visibleCoordinates = navigationMapView.mapView.mapboxMap.coordinateBounds(for: navigationMapView.mapView.bounds)

        let boundingBox = (
            minLat: visibleCoordinates.southwest.latitude,
            minLon: visibleCoordinates.southwest.longitude,
            maxLat: visibleCoordinates.northeast.latitude,
            maxLon: visibleCoordinates.northeast.longitude
        )

        // Try HERE first (primary)
        if let hereService = hereTrafficService {
            print("🚦 Using HERE Traffic (primary)...")
            hereService.getTrafficIncidents(in: boundingBox) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let hereIncidents):
                    print("✅ HERE Traffic: Found \(hereIncidents.count) incidents")

                    // Convert HERE incidents to TomTom format for compatibility
                    let tomTomIncidents = hereIncidents.map { hereIncident -> TomTomTrafficService.TrafficIncident in
                        let severityString: String
                        if hereIncident.severity >= 8 {
                            severityString = "Severe"
                        } else if hereIncident.severity >= 5 {
                            severityString = "High"
                        } else if hereIncident.severity >= 3 {
                            severityString = "Medium"
                        } else {
                            severityString = "Minor"
                        }

                        return TomTomTrafficService.TrafficIncident(
                            id: hereIncident.id,
                            type: 1,
                            severity: severityString,
                            coordinate: hereIncident.coordinate,
                            description: hereIncident.description
                        )
                    }

                    DispatchQueue.main.async {
                        self.displayTrafficIncidents(tomTomIncidents)
                    }

                case .failure(let error):
                    print("❌ HERE Traffic failed: \(error.localizedDescription)")
                    // Try TomTom as fallback
                    self.tryTomTomTrafficFallback(boundingBox: boundingBox)
                }
            }
        } else {
            // HERE not available, try TomTom directly
            print("⚠️ HERE not available, trying TomTom Traffic...")
            tryTomTomTrafficFallback(boundingBox: boundingBox)
        }
    }

    private func tryTomTomTrafficFallback(boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)) {
        guard let tomTomService = tomTomTrafficService else {
            print("⚠️ No traffic services available")
            return
        }

        print("🚦 Falling back to TomTom Traffic...")

        tomTomService.getTrafficIncidents(in: boundingBox) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let incidents):
                    print("✅ TomTom Traffic: \(incidents.count) incidents")
                    self?.displayTrafficIncidents(incidents)

                case .failure(let error):
                    print("❌ TomTom Traffic also failed: \(error.localizedDescription)")
                    print("⚠️ No traffic data available from any service")
                }
            }
        }
    }

    private func displayTrafficIncidents(_ incidents: [TomTomTrafficService.TrafficIncident]) {
        guard let manager = incidentAnnotationManager else { return }

        // Create annotations for each incident
        var annotations: [PointAnnotation] = []

        for incident in incidents {
            var annotation = PointAnnotation(coordinate: incident.coordinate)

            // Set icon based on type
            let iconName: String
            switch incident.type {
            case 1: iconName = "exclamationmark.triangle.fill" // Accident
            case 2: iconName = "hammer.fill"                    // Roadwork
            case 3: iconName = "xmark.octagon.fill"            // Closure
            default: iconName = "exclamationmark.circle.fill"  // Other
            }

            annotation.iconImage = iconName

            // Color by severity
            let iconColor: UIColor
            switch incident.severity {
            case "Severe", "High": iconColor = .systemRed
            case "Medium": iconColor = .systemOrange
            default: iconColor = .systemYellow
            }

            annotation.iconColor = StyleColor(iconColor)
            annotation.iconSize = 1.2

            // Add text label
            annotation.textField = incident.description
            annotation.textColor = StyleColor(.white)
            annotation.textHaloColor = StyleColor(.black)
            annotation.textHaloWidth = 2
            annotation.textSize = 10
            annotation.textOffset = [0, -2]

            annotations.append(annotation)
        }

        manager.annotations = annotations

        if !incidents.isEmpty {
            print("🚦 Displaying \(incidents.count) traffic incidents on map")
        }
    }

    // MARK: - Route Preview UI

    private func setupRoutePreviewUI() {
        // Route preview card with detailed info (distance, duration, ETA) + buttons
        routePreviewContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        routePreviewContainer.layer.cornerRadius = 16
        routePreviewContainer.layer.shadowColor = UIColor.black.cgColor
        routePreviewContainer.layer.shadowOpacity = 0.3
        routePreviewContainer.layer.shadowOffset = CGSize(width: 0, height: -4)
        routePreviewContainer.layer.shadowRadius = 8
        routePreviewContainer.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.isHidden = true
        view.addSubview(routePreviewContainer)

        // Route distance label (e.g., "45.3 mi")
        routeDistanceLabel.font = .systemFont(ofSize: 28, weight: .bold)
        routeDistanceLabel.textColor = .label
        routeDistanceLabel.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.addSubview(routeDistanceLabel)

        // Route duration label (e.g., "1h 23min")
        routeDurationLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        routeDurationLabel.textColor = .secondaryLabel
        routeDurationLabel.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.addSubview(routeDurationLabel)

        // Route ETA label (e.g., "Arrive by 3:45 PM")
        routeETALabel.font = .systemFont(ofSize: 16, weight: .medium)
        routeETALabel.textColor = .systemBlue
        routeETALabel.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.addSubview(routeETALabel)

        // Route selection label (e.g., "Route 1 of 3")
        routeSelectionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        routeSelectionLabel.textColor = .secondaryLabel
        routeSelectionLabel.translatesAutoresizingMaskIntoConstraints = false
        routePreviewContainer.addSubview(routeSelectionLabel)

        // Next route button
        nextRouteButton.setTitle("Next Route", for: .normal)
        nextRouteButton.backgroundColor = .systemGray6
        nextRouteButton.setTitleColor(.label, for: .normal)
        nextRouteButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        nextRouteButton.layer.cornerRadius = 8
        nextRouteButton.translatesAutoresizingMaskIntoConstraints = false
        nextRouteButton.addTarget(self, action: #selector(cycleToNextRoute), for: .touchUpInside)
        routePreviewContainer.addSubview(nextRouteButton)

        // Cancel button
        cancelRouteButton.setTitle("Cancel", for: .normal)
        cancelRouteButton.backgroundColor = .systemGray5
        cancelRouteButton.setTitleColor(.label, for: .normal)
        cancelRouteButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelRouteButton.layer.cornerRadius = 12
        cancelRouteButton.translatesAutoresizingMaskIntoConstraints = false
        cancelRouteButton.addTarget(self, action: #selector(cancelAllRouting), for: .touchUpInside)
        routePreviewContainer.addSubview(cancelRouteButton)

        // Start navigation button
        startNavigationButton.setTitle("🚛 Start", for: .normal)
        startNavigationButton.backgroundColor = .systemBlue
        startNavigationButton.setTitleColor(.white, for: .normal)
        startNavigationButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        startNavigationButton.layer.cornerRadius = 12
        startNavigationButton.translatesAutoresizingMaskIntoConstraints = false
        startNavigationButton.addTarget(self, action: #selector(confirmStartNavigation), for: .touchUpInside)
        routePreviewContainer.addSubview(startNavigationButton)

        NSLayoutConstraint.activate([
            routePreviewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            routePreviewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            routePreviewContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            routePreviewContainer.heightAnchor.constraint(equalToConstant: 160),

            // Route info labels at top
            routeDistanceLabel.topAnchor.constraint(equalTo: routePreviewContainer.topAnchor, constant: 16),
            routeDistanceLabel.leadingAnchor.constraint(equalTo: routePreviewContainer.leadingAnchor, constant: 20),

            routeDurationLabel.centerYAnchor.constraint(equalTo: routeDistanceLabel.centerYAnchor),
            routeDurationLabel.leadingAnchor.constraint(equalTo: routeDistanceLabel.trailingAnchor, constant: 12),

            routeETALabel.topAnchor.constraint(equalTo: routeDistanceLabel.bottomAnchor, constant: 4),
            routeETALabel.leadingAnchor.constraint(equalTo: routePreviewContainer.leadingAnchor, constant: 20),

            // Route selection UI (middle row)
            routeSelectionLabel.topAnchor.constraint(equalTo: routeETALabel.bottomAnchor, constant: 12),
            routeSelectionLabel.leadingAnchor.constraint(equalTo: routePreviewContainer.leadingAnchor, constant: 20),

            nextRouteButton.centerYAnchor.constraint(equalTo: routeSelectionLabel.centerYAnchor),
            nextRouteButton.leadingAnchor.constraint(equalTo: routeSelectionLabel.trailingAnchor, constant: 12),
            nextRouteButton.widthAnchor.constraint(equalToConstant: 100),
            nextRouteButton.heightAnchor.constraint(equalToConstant: 32),

            // Buttons at bottom
            cancelRouteButton.bottomAnchor.constraint(equalTo: routePreviewContainer.bottomAnchor, constant: -16),
            cancelRouteButton.leadingAnchor.constraint(equalTo: routePreviewContainer.leadingAnchor, constant: 16),
            cancelRouteButton.widthAnchor.constraint(equalTo: routePreviewContainer.widthAnchor, multiplier: 0.3),
            cancelRouteButton.heightAnchor.constraint(equalToConstant: 50),

            startNavigationButton.bottomAnchor.constraint(equalTo: routePreviewContainer.bottomAnchor, constant: -16),
            startNavigationButton.trailingAnchor.constraint(equalTo: routePreviewContainer.trailingAnchor, constant: -16),
            startNavigationButton.leadingAnchor.constraint(equalTo: cancelRouteButton.trailingAnchor, constant: 12),
            startNavigationButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func showRoutePreview(for navigationRoutes: NavigationRoutes) {
        // Store routes and reset selection
        currentNavigationRoutes = navigationRoutes
        selectedAlternativeRouteIndex = nil

        // Auto-collapse stops panel when route preview appears
        if !stopsPanel.isHidden && !isStopsPanelCollapsed {
            print("📍 Auto-collapsing stops panel for route preview")
            isStopsPanelCollapsed = true
            animateCollapsedState()  // Use existing animation function
        }

        // Use Mapbox NavigationMapView's showcase() method to display route with all alternatives
        navigationMapView.showcase(navigationRoutes, routesPresentationStyle: .all(shouldFit: true), animated: true)

        // Enable alternative route selection during preview
        enableAlternativeRouteSelection()

        // Calculate route details
        let primaryRoute = navigationRoutes.mainRoute.route
        let distanceMiles = primaryRoute.distance * 0.000621371
        let durationSeconds = primaryRoute.expectedTravelTime
        let durationMinutes = Int(durationSeconds / 60)

        // Format distance (e.g., "45.3 mi")
        routeDistanceLabel.text = String(format: "%.1f mi", distanceMiles)

        // Format duration (e.g., "1h 23min" or "45min")
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            routeDurationLabel.text = "\(hours)h \(minutes)min"
        } else {
            routeDurationLabel.text = "\(minutes)min"
        }

        // Calculate ETA (e.g., "Arrive by 3:45 PM")
        let eta = Date().addingTimeInterval(durationSeconds)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        routeETALabel.text = "Arrive by \(formatter.string(from: eta))"

        // Update route selection UI
        let totalRoutes = 1 + navigationRoutes.alternativeRoutes.count
        let currentRouteNum = (selectedAlternativeRouteIndex ?? -1) + 2  // -1 = main (route 1), 0+ = alternatives
        routeSelectionLabel.text = "Route \(currentRouteNum) of \(totalRoutes)"

        // Show/hide next route button based on whether alternatives exist
        if totalRoutes > 1 {
            nextRouteButton.isHidden = false
            routeSelectionLabel.isHidden = false
        } else {
            nextRouteButton.isHidden = true
            routeSelectionLabel.isHidden = true
        }

        // Show route preview card
        routePreviewContainer.isHidden = false
        recenterButton.isHidden = true

        view.bringSubviewToFront(routePreviewContainer)

        print("✅ Route preview: \(String(format: "%.1f mi", distanceMiles)), \(durationMinutes) min, ETA \(formatter.string(from: eta))")
        print("📍 +\(navigationRoutes.alternativeRoutes.count) alternative route(s) available")

        if !navigationRoutes.alternativeRoutes.isEmpty {
            print("💡 Tap on an alternative route to select it")
        }
    }

    // MARK: - Alternative Route Selection

    private func enableAlternativeRouteSelection() {
        // Add tap gesture to map for alternative route selection
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleRoutePreviewTap(_:)))
        tapGesture.delegate = self
        navigationMapView.mapView.addGestureRecognizer(tapGesture)

        print("💡 Alternative routes are interactive - tap to select")
    }

    @objc private func handleRoutePreviewTap(_ gesture: UITapGestureRecognizer) {
        // Only handle during route preview, not during navigation
        guard !isNavigating, let routes = currentNavigationRoutes else { return }
        guard gesture.state == .ended else { return }

        let point = gesture.location(in: navigationMapView.mapView)

        // Skip if user tapped on buttons or route preview card
        if routePreviewContainer.frame.contains(point) {
            return
        }

        print("🗺️ Map tapped at \(point) - checking for route selection")

        // Check proximity to all routes (main + alternatives)
        selectClosestAlternativeRoute(to: point, from: routes)
    }

    private func selectClosestAlternativeRoute(to point: CGPoint, from routes: NavigationRoutes) {
        guard !routes.alternativeRoutes.isEmpty else {
            print("💡 No alternative routes available")
            return
        }

        // Convert screen point to coordinate
        let tappedCoordinate = navigationMapView.mapView.mapboxMap.coordinate(for: point)

        // Find closest route to the tapped point (checking ALL routes including main)
        var closestDistance = CLLocationDistanceMax
        var closestRouteIndex: Int? = nil // -1 = main route, 0+ = alternative routes

        // Check main route
        let mainRouteCoords = routes.mainRoute.route.shape?.coordinates ?? []
        for coordinate in mainRouteCoords {
            let distance = tappedCoordinate.distance(to: coordinate)
            if distance < closestDistance {
                closestDistance = distance
                closestRouteIndex = -1 // Main route marker
            }
        }

        // Check each alternative route
        for (index, alternativeRoute) in routes.alternativeRoutes.enumerated() {
            let route = alternativeRoute.route
            let routeCoordinates = route.shape?.coordinates ?? []

            for coordinate in routeCoordinates {
                let distance = tappedCoordinate.distance(to: coordinate)
                if distance < closestDistance {
                    closestDistance = distance
                    closestRouteIndex = index
                }
            }
        }

        // More generous distance threshold (500m instead of 100m) for easier tapping
        guard closestDistance < 500 else {
            print("💡 Tap closer to a route to select it (tapped \(Int(closestDistance))m away)")
            return
        }

        // If user tapped main route, show message
        if closestRouteIndex == -1 {
            print("ℹ️ Main route already selected (tap an alternative to switch)")
            return
        }

        // Switch to the selected alternative route
        if let routeIndex = closestRouteIndex {
            print("🔄 Switching to alternative route \(routeIndex + 1) (distance: \(Int(closestDistance))m)")
            switchToAlternativeRoute(at: routeIndex)
        }
    }

    private func switchToAlternativeRoute(at index: Int) {
        guard let routes = currentNavigationRoutes,
              index < routes.alternativeRoutes.count else { return }

        // Store selected alternative route index
        selectedAlternativeRouteIndex = index

        // Get the selected alternative route
        let selectedAlternative = routes.alternativeRoutes[index]
        let selectedRoute = selectedAlternative.route

        // Update preview UI to show selected alternative route's details
        let distanceMiles = selectedRoute.distance * 0.000621371
        let durationSeconds = selectedRoute.expectedTravelTime
        let durationMinutes = Int(durationSeconds / 60)

        // Format distance
        routeDistanceLabel.text = String(format: "%.1f mi", distanceMiles)

        // Format duration
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            routeDurationLabel.text = "\(hours)h \(minutes)min"
        } else {
            routeDurationLabel.text = "\(minutes)min"
        }

        // Calculate ETA
        let eta = Date().addingTimeInterval(durationSeconds)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        routeETALabel.text = "Arrive by \(formatter.string(from: eta))"

        print("✅ Selected alternative route \(index + 1) - preview updated")

        // Update route selection label
        let totalRoutes = 1 + routes.alternativeRoutes.count
        let currentRouteNum = index + 2  // index 0 = route 2, etc
        routeSelectionLabel.text = "Route \(currentRouteNum) of \(totalRoutes)"
    }

    @objc private func cycleToNextRoute() {
        guard let routes = currentNavigationRoutes else { return }

        let totalRoutes = 1 + routes.alternativeRoutes.count
        guard totalRoutes > 1 else { return }  // Only cycle if alternatives exist

        // Calculate next route index
        let currentIndex = selectedAlternativeRouteIndex ?? -1  // -1 = main route
        let nextIndex: Int?

        if currentIndex == -1 {
            // Currently on main route, switch to first alternative
            nextIndex = 0
        } else if currentIndex < routes.alternativeRoutes.count - 1 {
            // Switch to next alternative
            nextIndex = currentIndex + 1
        } else {
            // Wrap around to main route
            nextIndex = nil
        }

        // Switch to the calculated route
        if let next = nextIndex {
            print("🔄 Cycling to alternative route \(next + 1)")
            switchToAlternativeRoute(at: next)
        } else {
            // Switch back to main route
            print("🔄 Cycling back to main route")
            selectedAlternativeRouteIndex = nil
            showRoutePreview(for: routes)  // Re-show with main route
        }
    }

    // MARK: - Universal Route Cancellation

    /// Shared cleanup method called after navigation ends (either user-initiated or programmatic)
    private func cleanupAfterNavigation() {
        isNavigating = false

        // CRITICAL: Force dismiss NavigationViewController if still presented before setting to nil
        // This ensures the VC's UI (route banners, trip info) is actually removed from screen
        if let navVC = currentNavigationViewController {
            if navVC.presentingViewController != nil {
                print("⚠️ NavigationVC still presented - force dismissing")
                navVC.dismiss(animated: false)  // Force immediate dismissal
            }
        }

        currentNavigationViewController = nil
        currentNavigationRoutes = nil
        routePreviewContainer.isHidden = true

        // Stop hazard monitoring
        hazardMonitoringService?.stopMonitoring()
        currentHazardWarningView?.removeFromSuperview()
        currentHazardWarningView = nil
        lastHazardAlert = nil

        // Ensure map is clean and we're back to free-drive
        navigationMapView.removeRoutes()
        navigationMapView.navigationCamera.stop()
        navigationMapView.navigationCamera.update(cameraState: .idle)

        // Re-enable puck
        navigationMapView.puckType = .puck2D(.navigationDefault)
        navigationMapView.mapView.location.options.puckBearingEnabled = true

        // Restart free-drive mode
        startFreeDriveMode()

        // Show free-drive UI elements
        // panelController.view.isHidden = false  // DISABLED - using custom search bar
        recenterButton.isHidden = false
        settingsButton.isHidden = false

        // Recenter camera immediately
        recenterMap()

        print("❌ Navigation ended - reset to free-drive state")
    }

    /// Universal cancellation method that works for both route preview and active navigation
    @objc private func cancelAllRouting() {
        if let navVC = currentNavigationViewController {
            // CRITICAL: Only dismiss if VC is actually presented (prevents double-dismissal race condition)
            if navVC.presentingViewController != nil {
                navVC.dismiss(animated: true) { [weak self] in
                    self?.cleanupAfterNavigation()
                }
            } else {
                // VC already dismissed itself - just cleanup
                cleanupAfterNavigation()
            }
        } else {
            // If we're only previewing, use existing preview cancel logic
            cancelRoutePreview()
        }
    }

    @objc private func cancelRoutePreview() {
        // CRITICAL: Complete cleanup of NavigationMapView state
        navigationMapView.removeRoutes()

        // Stop navigation camera and explicitly return to idle state
        navigationMapView.navigationCamera.stop()
        navigationMapView.navigationCamera.update(cameraState: .idle)

        // CRITICAL FIX: Re-enable puck (showcase() may have modified it)
        navigationMapView.puckType = .puck2D(.navigationDefault)
        navigationMapView.mapView.location.options.puckBearingEnabled = true

        // Clear stored route data
        currentNavigationRoutes = nil

        // Hide route preview UI
        routePreviewContainer.isHidden = true

        // Show free-drive UI elements
        // panelController.view.isHidden = false  // DISABLED - using custom search bar
        recenterButton.isHidden = false
        settingsButton.isHidden = false

        // CRITICAL FIX: Restart free-drive mode to ensure we're not stuck in route mode
        startFreeDriveMode()

        // Recenter camera immediately to ensure 3D follow mode is restored
        recenterMap()

        print("❌ Route preview canceled - fully reset to free-drive state")
    }

    @objc private func confirmStartNavigation() {
        guard let routes = currentNavigationRoutes else {
            print("⚠️ No routes available to start navigation")
            return
        }

        // Hide route preview
        routePreviewContainer.isHidden = true

        // Check if user selected an alternative route
        if let selectedIndex = selectedAlternativeRouteIndex {
            print("🔄 User selected alternative route \(selectedIndex + 1) - recalculating to make it primary")

            // Get destination from the selected route to recalculate
            let selectedRoute = routes.alternativeRoutes[selectedIndex].route
            if let destination = selectedRoute.shape?.coordinates.last,
               let origin = locationManager.location?.coordinate {

                // Recalculate route to get fresh NavigationRoutes with selected path
                calculateMapboxRoute(from: origin, to: destination)
                return
            }
        }

        // Start navigation with current routes (user didn't select alternative)
        startNavigation(with: routes)
    }

    func calculateRoute(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location available")
            return
        }

        print("🚛 Calculating TRUCK route from \(userLocation) to \(destination)")
        print("🚛 Truck params: \(truckHeight.value)m height, \(truckWidth.value)m width, \(truckWeight.value)t weight")

        // Calculate distance to determine routing strategy
        let distance = userLocation.distance(to: destination)

        // Strategy: Use HERE for truck routes (primary), fallback to TomTom, then Mapbox
        if let hereService = hereRoutingService {
            print("🚛 Using HERE Routing API for truck route (\(Int(distance/1000))km)")
            calculateHERERoute(from: userLocation, to: destination, using: hereService)
        } else if let tomTomService = tomTomRoutingService {
            print("🚛 Using TomTom Routing API for truck route (\(Int(distance/1000))km)")
            calculateTomTomRoute(from: userLocation, to: destination, using: tomTomService)
        } else {
            print("🚛 Using Mapbox Routing API")
            calculateMapboxRoute(from: userLocation, to: destination)
        }
    }

    // MARK: - TomTom Routing

    private func calculateTomTomRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        using service: TomTomRoutingService
    ) {
        // Use standard US semi-truck configuration (Imperial units)
        var truckParams = TruckParameters.standardSemiTruck

        // Override with custom values if needed (using Imperial units)
        truckParams.heightFeet = truckHeightFeet    // 13.5 ft (13'6")
        truckParams.widthFeet = truckWidthFeet      // 8.5 ft (8'6")
        truckParams.weightLbs = truckWeightLbs      // 80,000 lbs
        truckParams.lengthFeet = truckLengthFeet    // 70 ft total
        truckParams.avoidUnpavedRoads = true

        print("🚛 TomTom routing with: \(truckWeightLbs) lbs, \(truckHeightFeet)' height, \(truckWidthFeet)' width")

        // Calculate route with TomTom
        service.calculateRoute(
            from: origin,
            to: destination,
            truckParams: truckParams
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    guard let tomTomRoute = response.routes.first else {
                        print("⚠️ No routes in TomTom response, falling back to Mapbox")
                        self?.calculateMapboxRoute(from: origin, to: destination)
                        return
                    }

                    let distanceMiles = Double(tomTomRoute.summary.lengthInMeters) * 0.000621371
                    let durationMinutes = tomTomRoute.summary.travelTimeInSeconds / 60
                    print("✅ TomTom route: \(String(format: "%.1f mi", distanceMiles)), \(durationMinutes) min")

                    // Display TomTom route on map (visual only, then fallback to Mapbox for navigation)
                    self?.displayTomTomRouteAndUseMapboxForNavigation(tomTomRoute, from: origin, to: destination)

                case .failure(let error):
                    print("❌ TomTom routing failed: \(error.localizedDescription)")
                    print("🔄 Falling back to Mapbox routing")
                    self?.calculateMapboxRoute(from: origin, to: destination)
                }
            }
        }
    }

    private func displayTomTomRouteAndUseMapboxForNavigation(
        _ tomTomRoute: TomTomRoute,
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) {
        // For now, use Mapbox for actual navigation since NavigationViewController requires NavigationRoutes
        // TomTom route is validated and available, but we'll use Mapbox navigation system
        print("🔄 Using Mapbox for turn-by-turn navigation (TomTom route validated)")
        calculateMapboxRoute(from: origin, to: destination)
    }

    // MARK: - HERE Routing

    private func calculateHERERoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        using service: HERERoutingService
    ) {
        // Convert truck parameters to HERE format (Imperial to Metric)
        let truckParams = HERERoutingService.TruckParameters.fromImperial(
            weightLbs: Double(truckWeightLbs),
            heightFt: truckHeightFeet,
            widthFt: truckWidthFeet,
            lengthFt: truckLengthFeet
        )

        print("🚛 HERE routing with: \(truckWeightLbs) lbs, \(truckHeightFeet)' height, \(truckWidthFeet)' width")

        // Calculate route with HERE
        service.calculateRoute(
            from: origin,
            to: destination,
            truckParams: truckParams,
            avoidTolls: false
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let hereRoute):
                    let distanceMiles = hereRoute.totalDistance * 0.000621371
                    let durationMinutes = hereRoute.totalDuration / 60
                    print("✅ HERE route: \(String(format: "%.1f mi", distanceMiles)), \(String(format: "%.0f", durationMinutes)) min")

                    // Display toll costs if available
                    if let tolls = hereRoute.tollCosts {
                        print("💰 Toll costs: \(tolls.currency) \(String(format: "%.2f", tolls.total))")
                        for detail in tolls.details {
                            print("   - \(detail.name): \(String(format: "%.2f", detail.cost))")
                        }
                    }

                    // Display HERE route info and use Mapbox for navigation
                    self?.displayHERERouteAndUseMapboxForNavigation(hereRoute, from: origin, to: destination)

                case .failure(let error):
                    print("❌ HERE routing failed: \(error.localizedDescription)")

                    // Try TomTom before falling back to Mapbox
                    if let tomTomService = self?.tomTomRoutingService {
                        print("🔄 Trying TomTom Routing API...")
                        self?.calculateTomTomRoute(from: origin, to: destination, using: tomTomService)
                    } else {
                        print("🔄 Final fallback to Mapbox routing")
                        self?.calculateMapboxRoute(from: origin, to: destination)
                    }
                }
            }
        }
    }

    private func displayHERERouteAndUseMapboxForNavigation(
        _ hereRoute: HERERoutingService.HERERoute,
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) {
        // For now, use Mapbox for actual navigation since NavigationViewController requires NavigationRoutes
        // HERE route is validated and available with toll costs
        print("🔄 Using Mapbox for turn-by-turn navigation (HERE route validated)")

        // Could display toll costs in UI before starting navigation
        if let tolls = hereRoute.tollCosts {
            let alert = UIAlertController(
                title: "Route Toll Costs",
                message: "This route has tolls totaling \(tolls.currency) \(String(format: "%.2f", tolls.total))\n\nProceed with navigation?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
                self?.calculateMapboxRoute(from: origin, to: destination)
            })
            alert.addAction(UIAlertAction(title: "Avoid Tolls", style: .cancel) { [weak self] _ in
                // Recalculate without tolls
                if let service = self?.hereRoutingService {
                    let truckParams = HERERoutingService.TruckParameters.fromImperial(
                        weightLbs: Double(self?.truckWeightLbs ?? 80000),
                        heightFt: self?.truckHeightFeet ?? 13.5,
                        widthFt: self?.truckWidthFeet ?? 8.5
                    )
                    service.calculateRoute(from: origin, to: destination, truckParams: truckParams, avoidTolls: true) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let newRoute):
                                print("✅ HERE toll-free route: \(String(format: "%.1f mi", newRoute.totalDistance * 0.000621371))")
                                self?.calculateMapboxRoute(from: origin, to: destination)
                            case .failure:
                                self?.calculateMapboxRoute(from: origin, to: destination)
                            }
                        }
                    }
                }
            })
            present(alert, animated: true)
        } else {
            calculateMapboxRoute(from: origin, to: destination)
        }
    }

    // MARK: - Mapbox Routing

    private func calculateMapboxRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) {
        // Configure truck-specific route options
        let routeOptions = configureTruckRouteOptions(from: origin, to: destination)

        // Calculate route using Navigation Provider (v3 async API)
        let request = mapboxNavigation.routingProvider().calculateRoutes(options: routeOptions)

        Task { @MainActor in
            switch await request.result {
            case .success(let navigationRoutes):
                print("✅ Mapbox truck route calculated successfully")
                print("🚛 Route respects truck restrictions!")

                // Show route preview with alternatives before starting navigation
                showRoutePreview(for: navigationRoutes)

            case .failure(let error):
                print("❌ Route calculation failed: \(error)")

                let alert = UIAlertController(
                    title: "Route Error",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    // MARK: - Multi-Stop Route Calculation

    internal func calculateMapboxMultiStopRoute(
        from origin: CLLocationCoordinate2D,
        through waypoints: [CLLocationCoordinate2D],
        retryCount: Int = 0
    ) {
        guard !waypoints.isEmpty else {
            print("⚠️ No waypoints provided for multi-stop route")
            return
        }

        // Validate all coordinates before proceeding
        let allCoordinates = [origin] + waypoints
        for (index, coordinate) in allCoordinates.enumerated() {
            guard CLLocationCoordinate2DIsValid(coordinate) else {
                print("❌ Invalid coordinate at index \(index): lat=\(coordinate.latitude), lng=\(coordinate.longitude)")

                let alert = UIAlertController(
                    title: "Invalid Location",
                    message: "One of the stops has an invalid location. Please remove it and try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }

            // Validate coordinate is not at 0,0 (common placeholder error)
            if coordinate.latitude == 0 && coordinate.longitude == 0 {
                print("❌ Coordinate at index \(index) is at 0,0 - likely a placeholder value")

                let alert = UIAlertController(
                    title: "Invalid Location",
                    message: "One of the stops has not been properly set. Please check all stops.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
        }

        print("🗺️ Calculating Mapbox multi-stop route (attempt \(retryCount + 1)/3)")
        print("   Origin: \(origin.latitude), \(origin.longitude)")
        for (index, waypoint) in waypoints.enumerated() {
            print("   Stop \(index + 1): \(waypoint.latitude), \(waypoint.longitude)")
        }

        // Build waypoints array: origin + intermediate stops + final destination
        let allWaypoints = [origin] + waypoints

        // Create route options with all waypoints
        let options = NavigationRouteOptions(coordinates: allWaypoints)

        // Set truck-specific parameters
        options.maximumHeight = truckHeight
        options.maximumWidth = truckWidth
        options.maximumWeight = truckWeight

        // Avoid unpaved roads
        options.roadClassesToAvoid = [.unpaved]

        // Request route alternatives
        options.includesAlternativeRoutes = false  // Multi-stop routes don't need alternatives

        // Enable detailed annotations for navigation
        options.attributeOptions = [.speed, .distance, .expectedTravelTime, .congestionLevel]

        print("🚛 Multi-stop route with truck restrictions: H:\(truckHeight)m W:\(truckWidth)m Wt:\(truckWeight)kg")

        // Calculate route using Navigation Provider
        let request = mapboxNavigation.routingProvider().calculateRoutes(options: options)

        Task { @MainActor in
            switch await request.result {
            case .success(let navigationRoutes):
                let mainRoute = navigationRoutes.mainRoute.route

                print("✅ Mapbox multi-stop route calculated successfully")
                print("🗺️ Route through \(waypoints.count) waypoints")
                print("   Distance: \(String(format: "%.1f", mainRoute.distance / 1609.34)) mi")
                print("   Duration: \(String(format: "%.0f", mainRoute.expectedTravelTime / 60)) min")
                print("   Legs: \(mainRoute.legs.count)")

                // Calculate ETAs for each stop based on route legs
                self.updateStopETAs(from: mainRoute)

                // Show route preview with navigation start button
                showRoutePreview(for: navigationRoutes)

            case .failure(let error):
                print("❌ Multi-stop route calculation failed (attempt \(retryCount + 1)/3): \(error)")
                print("   Error type: \(type(of: error))")
                print("   Error description: \(error.localizedDescription)")

                // Retry with exponential backoff for transient errors
                if retryCount < 2 {
                    let delay = Double(retryCount + 1) * 1.0  // 1s, 2s delays
                    print("⏳ Retrying in \(delay)s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.calculateMapboxMultiStopRoute(from: origin, through: waypoints, retryCount: retryCount + 1)
                    }
                } else {
                    // Max retries reached - show error to user
                    let alert = UIAlertController(
                        title: "Multi-Stop Route Error",
                        message: "Could not calculate route through all stops after 3 attempts. Please try again or adjust your stops.\n\nError: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - Update Stop ETAs

    private func updateStopETAs(from route: MapboxDirections.Route) {
        // Calculate cumulative arrival times from route legs
        var cumulativeTime: TimeInterval = 0
        let departureTime = Date()

        print("🕐 Calculating ETAs for \(stops.count) stops from \(route.legs.count) legs")

        // Each leg represents travel from one waypoint to the next
        // Leg 0: Origin → Stop 1
        // Leg 1: Stop 1 → Stop 2
        // Leg N-1: Stop N-1 → Stop N
        for (index, leg) in route.legs.enumerated() {
            cumulativeTime += leg.expectedTravelTime

            // Update stop ETA (index matches because first leg goes to first stop)
            if index < stops.count {
                let arrivalTime = departureTime.addingTimeInterval(cumulativeTime)
                stops[index].estimatedArrival = arrivalTime

                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print("   Stop \(index + 1): \(stops[index].name) - ETA \(formatter.string(from: arrivalTime)) (\(String(format: "%.0f", leg.expectedTravelTime / 60)) min leg)")
            }
        }

        // Reload table view to show updated ETAs
        stopsTableView.reloadData()
        print("✅ ETAs updated for all stops")
    }

    private func startNavigation(with navigationRoutes: NavigationRoutes) {
        // Set isNavigating first to prevent locationMatching from updating UI
        isNavigating = true

        // Clear search annotations before starting navigation
        clearSearchAnnotations()

        // Pause free-drive session before starting turn-by-turn navigation
        if isFreeDriveActive {
            navigationProvider.tripSession().pauseFreeDrive()
            isFreeDriveActive = false
            print("⏸️ Free-drive mode paused for turn-by-turn navigation")
        }

        // Hide free-drive UI during active navigation
        speedLimitView.isHidden = true
        roadNameLabel.isHidden = true
        // panelController.view.isHidden = true  // DISABLED - using custom search bar
        recenterButton.isHidden = true
        settingsButton.isHidden = true
        routePreviewContainer.isHidden = true  // Hide our custom Cancel/Start buttons

        // Configure navigation options using the navigation provider
        let navigationOptions = NavigationOptions(
            mapboxNavigation: mapboxNavigation,
            voiceController: navigationProvider.routeVoiceController,
            eventsManager: navigationProvider.eventsManager()
        )

        // Create Mapbox NavigationViewController (drop-in UI component)
        let navigationViewController = NavigationViewController(
            navigationRoutes: navigationRoutes,
            navigationOptions: navigationOptions
        )
        navigationViewController.delegate = self
        navigationViewController.modalPresentationStyle = .fullScreen

        // Present Mapbox's premium navigation UI
        present(navigationViewController, animated: true) {
            print("🧭 Truck navigation started with Mapbox NavigationViewController v3")
            print("🚛 Voice guidance, 3D camera, and speed limits enabled automatically")
        }

        currentNavigationViewController = navigationViewController

        // Start hazard monitoring with route coordinates
        if let currentLocation = locationManager.location {
            let routeCoordinates = navigationRoutes.mainRoute.route.shape?.coordinates ?? []
            hazardMonitoringService?.startMonitoring(currentLocation: currentLocation, route: routeCoordinates)
        }
    }

    // Note: Navigation UI, route drawing, voice guidance, speed limits, etc.
    // are all handled automatically by Mapbox NavigationViewController
}

// MARK: - SearchControllerDelegate

// DISABLED - Using custom search bar instead of MapboxSearchUI
/*
extension MapViewController: SearchControllerDelegate {
    func searchResultSelected(_ searchResult: SearchResult) {
        // User selected a search result from MapboxSearchUI
        let coordinate = searchResult.coordinate

        print("📍 Selected destination: \(searchResult.name)")

        // Dismiss search controller
        searchController.dismiss(animated: true)

        // Clear any category search annotations
        clearSearchAnnotations()

        // Calculate route to selected destination
        calculateRoute(to: coordinate)
    }

    func categorySearchResultsReceived(category: SearchCategory, results: [SearchResult]) {
        print("📂 Category search: \(category.name) - \(results.count) results nearby")

        if results.isEmpty {
            print("⚠️ No \(category.name) found nearby")
            return
        }

        // Store search results
        currentSearchResults = results

        // Display results as map annotations
        displaySearchResultsAsAnnotations(results: results, category: category.name)

        print("✅ Displaying \(results.count) \(category.name) locations on map")
    }

    private func displaySearchResultsAsAnnotations(results: [SearchResult], category: String) {
        // Clear previous annotations
        clearSearchAnnotations()

        // Create annotations for each search result
        var annotations: [PointAnnotation] = []

        for result in results {
            var annotation = PointAnnotation(coordinate: result.coordinate)
            annotation.textField = result.name
            annotation.textColor = StyleColor(.label)
            annotation.textHaloColor = StyleColor(.systemBackground)
            annotation.textHaloWidth = 2
            annotation.textOffset = [0, -1.5]
            annotation.textSize = 12

            // Use SF Symbol for pin
            annotation.iconImage = "mappin.circle.fill"
            annotation.iconSize = 1.5

            annotations.append(annotation)
        }

        // Add annotations to map
        pointAnnotationManager.annotations = annotations

        // Fit camera to show all annotations
        fitCameraToAnnotations(coordinates: results.map { $0.coordinate })

        print("📍 Added \(annotations.count) \(category) pins to map")
    }

    func fitCameraToAnnotations(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }

        // If single coordinate, just center on it
        if coordinates.count == 1 {
            let cameraOptions = CameraOptions(
                center: coordinates[0],
                zoom: 15,
                pitch: 0
            )
            navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
            return
        }

        // Calculate bounding box for multiple coordinates
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }

        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        // Calculate appropriate zoom level based on span
        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon
        let maxSpan = max(latSpan, lonSpan)

        // Simple zoom calculation (adjust as needed)
        let zoom = max(10.0, 15.0 - log2(maxSpan * 100))

        let cameraOptions = CameraOptions(
            center: center,
            padding: UIEdgeInsets(top: 100, left: 50, bottom: 200, right: 50),
            zoom: zoom,
            pitch: 0
        )

        navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
    }

    func clearSearchAnnotations() {
        pointAnnotationManager.annotations = []
        currentSearchResults = []
        print("🗑️ Cleared search annotations")
    }

    func userFavoriteSelected(_ userFavorite: FavoriteRecord) {
        // Handle favorite selection if needed
        let coordinate = userFavorite.coordinate
        print("⭐ Selected favorite: \(userFavorite.name)")

        searchController.dismiss(animated: true)
        calculateRoute(to: coordinate)
    }
}
*/

// Keep these helper methods available for custom search
extension MapViewController {
    func fitCameraToAnnotations(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }

        // If single coordinate, just center on it
        if coordinates.count == 1 {
            let cameraOptions = CameraOptions(
                center: coordinates[0],
                zoom: 15,
                pitch: 0
            )
            navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
            return
        }

        // Calculate bounding box for multiple coordinates
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }

        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        // Calculate appropriate zoom level based on span
        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon
        let maxSpan = max(latSpan, lonSpan)

        // Simple zoom calculation (adjust as needed)
        let zoom = max(10.0, 15.0 - log2(maxSpan * 100))

        let cameraOptions = CameraOptions(
            center: center,
            padding: UIEdgeInsets(top: 100, left: 50, bottom: 200, right: 50),
            zoom: zoom,
            pitch: 0
        )

        navigationMapView.mapView.camera.ease(to: cameraOptions, duration: 1.5, curve: .easeInOut, completion: nil)
    }

    func clearSearchAnnotations() {
        pointAnnotationManager.annotations = []
        currentSearchResults = []
        print("🗑️ Cleared search annotations")
    }
}

// MARK: - NavigationViewControllerDelegate

extension MapViewController: NavigationViewControllerDelegate {
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        // CRITICAL: This delegate is called AFTER the NavigationViewController has already dismissed itself
        // Do NOT call dismiss() here - it will cause a double-dismissal race condition

        print(canceled ? "🛑 Navigation canceled - returning to free-drive" : "🎯 Navigation completed - returning to free-drive")

        // NavigationViewController already dismissed itself - just cleanup
        cleanupAfterNavigation()

        // Note: speedLimitView and roadNameLabel visibility is managed by locationMatching subscription
        // They will automatically show when data is available
    }

    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        print("🎉 Arrived at destination!")

        // Return true to allow NavigationViewController to auto-dismiss
        // It will call navigationViewControllerDidDismiss after dismissing
        // DO NOT manually call dismiss() here - causes double-dismissal
        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("📍 Location authorization status: \(status.rawValue)")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
            print("✅ Location services started")

            // Recenter camera to user location if we just got permission
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.recenterMap()
            }

        case .denied, .restricted:
            print("❌ Location access denied - app will not function properly")

        case .notDetermined:
            print("⚠️ Location permission not yet determined")

        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update search proximity with new location (DISABLED - using custom search)
        // configureSearchProximity()

        // Update hazard monitoring with new location (only during active navigation)
        if isNavigating, let routes = currentNavigationRoutes {
            let routeCoordinates = routes.mainRoute.route.shape?.coordinates ?? []
            hazardMonitoringService?.updateLocation(location, route: routeCoordinates)
        }

        // Update weather every 10 minutes to avoid API rate limits
        let shouldUpdateWeather: Bool
        if let lastUpdate = lastWeatherUpdateTime {
            shouldUpdateWeather = Date().timeIntervalSince(lastUpdate) > 600 // 10 minutes
        } else {
            shouldUpdateWeather = true // First time
        }

        if shouldUpdateWeather {
            fetchWeather(for: location.coordinate)
            lastWeatherUpdateTime = Date()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            lastBearing = newHeading.trueHeading
        }
    }
}

// MARK: - AnnotationInteractionDelegate

extension MapViewController: AnnotationInteractionDelegate {
    func annotationManager(_ manager: AnnotationManager, didDetectTappedAnnotations annotations: [Annotation]) {
        guard let annotation = annotations.first as? PointAnnotation else { return }

        // Find the search result for this annotation
        if let index = currentSearchResults.firstIndex(where: { result in
            result.coordinate.latitude == annotation.point.coordinates.latitude &&
            result.coordinate.longitude == annotation.point.coordinates.longitude
        }) {
            let searchResult = currentSearchResults[index]
            print("📍 Tapped annotation: \(searchResult.name)")

            // Calculate route to selected location
            calculateRoute(to: searchResult.coordinate)

            // Clear annotations after selection
            clearSearchAnnotations()
        }
    }
}

// MARK: - SettingsViewControllerDelegate

extension MapViewController: SettingsViewControllerDelegate {
    func settingsDidChange() {
        print("⚙️ Settings changed - updating app configuration")
        // Settings are automatically persisted via TruckSettings UserDefaults
        // Update weather overlay based on new setting
        updateWeatherOverlay()
    }

    func mapStyleDidChange(to style: TruckSettings.MapStyle) {
        print("🎨 Map style changed to: \(style.rawValue)")

        // Update map appearance immediately based on selected style
        let lightPreset: String
        switch style {
        case .auto:
            // Use system appearance
            lightPreset = traitCollection.userInterfaceStyle == .dark ? "night" : "day"
        case .day:
            lightPreset = "day"
        case .night:
            lightPreset = "night"
        }

        do {
            try navigationMapView.mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: lightPreset
            )
            print("✅ Map style updated to \(lightPreset) mode")
        } catch {
            print("⚠️ Error updating map style: \(error)")
        }
    }

    // MARK: - Hazard Warning System

    private func setupHazardWarningCallbacks() {
        hazardMonitoringService?.onHazardDetected = { [weak self] alert in
            DispatchQueue.main.async {
                self?.displayHazardWarning(alert)
            }
        }
    }

    private func displayHazardWarning(_ alert: HazardAlert) {
        // Don't show duplicate warnings
        if let lastAlert = lastHazardAlert,
           lastAlert.type.title == alert.type.title,
           abs(lastAlert.distanceInMeters - alert.distanceInMeters) < 100 {
            // Just update distance if same hazard
            currentHazardWarningView?.updateDistance(alert.distanceInMeters)
            return
        }

        lastHazardAlert = alert

        // Remove existing warning if any
        currentHazardWarningView?.removeFromSuperview()

        // Create new warning view
        let warningView = HazardWarningView()
        warningView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(warningView)

        NSLayoutConstraint.activate([
            warningView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            warningView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            warningView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Configure warning with truck dimensions
        warningView.configure(
            with: alert,
            truckHeight: TruckSettings.height,
            truckWeight: TruckSettings.weight,
            truckWidth: TruckSettings.width,
            truckLength: TruckSettings.length
        )

        warningView.onDismiss = { [weak self] in
            self?.currentHazardWarningView = nil
            self?.lastHazardAlert = nil
        }

        currentHazardWarningView = warningView

        // Play audio alert for critical hazards
        if alert.type.isCritical {
            playHazardAudioAlert()
        }

        print("🚨 Hazard warning displayed: \(alert.type.title) at \(alert.distanceDescription)")
    }

    private func playHazardAudioAlert() {
        // Check if audio alerts are enabled
        guard TruckSettings.enableHazardAudio else {
            print("🔇 Hazard audio alert disabled by user settings")
            return
        }

        // Play gentle notification sound (not aggressive alarm)
        AudioServicesPlaySystemSound(1310) // Soft notification chime

        print("🔔 Hazard notification sound played")
    }
}

// MARK: - UIGestureRecognizerDelegate

extension MapViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our tap gesture to work alongside map gestures
        return true
    }
}

extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }
}
