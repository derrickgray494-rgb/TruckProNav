//
//  WeatherOverlayService.swift
//  TruckNavPro
//
//  RainViewer API integration for live weather radar overlay
//

import Foundation
import MapboxMaps

// MARK: - RainViewer API Models

struct RainViewerResponse: Codable {
    let host: String
    let radar: RadarData

    struct RadarData: Codable {
        let past: [RadarFrame]
        let nowcast: [RadarFrame]

        struct RadarFrame: Codable {
            let time: Int
            let path: String
        }
    }
}

// MARK: - Weather Overlay Service

class WeatherOverlayService {

    private let apiURL = "https://api.rainviewer.com/public/weather-maps.json"
    private var currentFrameIndex: Int = 0
    private var radarFrames: [RainViewerResponse.RadarData.RadarFrame] = []
    private var baseURL: String = ""

    private var weatherSourceId = "weather-radar-source"
    private var weatherLayerId = "weather-radar-layer"

    // MARK: - Public Methods

    /// Fetch latest weather radar data from RainViewer
    func fetchWeatherData(completion: @escaping (Result<RainViewerResponse, Error>) -> Void) {
        guard let url = URL(string: apiURL) else {
            completion(.failure(NSError(domain: "WeatherOverlay", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "WeatherOverlay", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let weatherResponse = try decoder.decode(RainViewerResponse.self, from: data)
                completion(.success(weatherResponse))
            } catch {
                print("⚠️ Weather: Decode error - \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    /// Add weather radar overlay to Mapbox map
    func addWeatherOverlay(to mapView: MapView, completion: @escaping (Bool) -> Void) {
        fetchWeatherData { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                self.baseURL = response.host
                self.radarFrames = response.radar.past + response.radar.nowcast

                guard !self.radarFrames.isEmpty else {
                    print("⚠️ Weather: No radar frames available")
                    completion(false)
                    return
                }

                // Use the most recent frame
                self.currentFrameIndex = self.radarFrames.count - 1
                let latestFrame = self.radarFrames[self.currentFrameIndex]

                DispatchQueue.main.async {
                    self.setupWeatherLayer(on: mapView, frame: latestFrame)
                    print("🌧️ Weather overlay added successfully")
                    completion(true)
                }

            case .failure(let error):
                print("⚠️ Weather: Failed to fetch data - \(error.localizedDescription)")
                completion(false)
            }
        }
    }

    /// Remove weather radar overlay from map
    func removeWeatherOverlay(from mapView: MapView) {
        DispatchQueue.main.async {
            do {
                // Try to remove layer (will throw if doesn't exist)
                try mapView.mapboxMap.removeLayer(withId: self.weatherLayerId)
                print("🌧️ Weather layer removed")
            } catch {
                // Layer doesn't exist, that's fine
            }

            do {
                // Try to remove source (will throw if doesn't exist)
                try mapView.mapboxMap.removeSource(withId: self.weatherSourceId)
                print("🌧️ Weather source removed")
            } catch {
                // Source doesn't exist, that's fine
            }
        }
    }

    // MARK: - Private Methods

    private func setupWeatherLayer(on mapView: MapView, frame: RainViewerResponse.RadarData.RadarFrame) {
        // Remove existing layer and source if present
        removeWeatherOverlay(from: mapView)

        // Build tile URL with RainViewer format
        // Format: https://tilecache.rainviewer.com/v2/radar/{time}/{tileSize}/{z}/{x}/{y}/{color}/{options}.png
        let tileURL = "\(baseURL)\(frame.path)/256/{z}/{x}/{y}/6/1_1.png"

        print("🌧️ Weather tile URL: \(tileURL)")

        do {
            // Create raster source
            var rasterSource = RasterSource(id: weatherSourceId)
            rasterSource.tiles = [tileURL]
            rasterSource.tileSize = 256
            rasterSource.minzoom = 0
            rasterSource.maxzoom = 12

            // Add source to map
            try mapView.mapboxMap.addSource(rasterSource)

            // Create raster layer
            var rasterLayer = RasterLayer(id: weatherLayerId, source: weatherSourceId)
            rasterLayer.rasterOpacity = .constant(0.6) // 60% opacity for better visibility
            rasterLayer.rasterFadeDuration = .constant(300) // Smooth transitions

            // Add layer below labels but above roads
            // Try to add it below "road-label" or similar
            if let labelLayerId = findLabelLayer(in: mapView) {
                try mapView.mapboxMap.addLayer(rasterLayer, layerPosition: .below(labelLayerId))
            } else {
                // Fallback: add layer on top
                try mapView.mapboxMap.addLayer(rasterLayer)
            }

            print("🌧️ Weather radar layer added successfully")

        } catch {
            print("⚠️ Weather: Error adding layer - \(error)")
        }
    }

    private func findLabelLayer(in mapView: MapView) -> String? {
        // Try to find a label layer to insert weather overlay below it
        let possibleLabelLayers = [
            "road-label",
            "poi-label",
            "transit-label",
            "place-label",
            "waterway-label"
        ]

        // Try each layer and return the first one that exists
        for layerId in possibleLabelLayers {
            do {
                // Try to get layer properties (will throw if doesn't exist)
                _ = try mapView.mapboxMap.layer(withId: layerId)
                return layerId
            } catch {
                // Layer doesn't exist, try next one
                continue
            }
        }

        return nil
    }

    /// Animate through weather frames (for future enhancement)
    func animateWeatherFrames(on mapView: MapView, interval: TimeInterval = 0.5) {
        guard !radarFrames.isEmpty else { return }

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // Cycle through frames
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.radarFrames.count
            let frame = self.radarFrames[self.currentFrameIndex]

            DispatchQueue.main.async {
                self.setupWeatherLayer(on: mapView, frame: frame)
            }
        }
    }
}
