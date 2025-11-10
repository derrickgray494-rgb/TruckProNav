//
//  WeatherService.swift
//  TruckNavPro
//

import Foundation
import CoreLocation

struct WeatherInfo {
    let temperature: Int
    let high: Int
    let low: Int
    let condition: String
    let symbolName: String
    let dayName: String
}

struct WeatherData: Codable {
    let main: Main
    let weather: [Weather]

    struct Main: Codable {
        let temp: Double
        let tempMin: Double
        let tempMax: Double

        enum CodingKeys: String, CodingKey {
            case temp
            case tempMin = "temp_min"
            case tempMax = "temp_max"
        }
    }

    struct Weather: Codable {
        let id: Int
        let main: String
        let description: String
    }
}

class WeatherService {

    static let shared = WeatherService()

    private init() {}

    private var apiKey: String {
        // Load from Info.plist (key already configured)
        guard let apiKey = Bundle.main.infoDictionary?["OpenWeatherKey"] as? String else {
            print("⚠️ OpenWeatherKey not found in Info.plist")
            return ""
        }
        return apiKey

    }

    func fetchWeather(for coordinate: CLLocationCoordinate2D, completion: @escaping (Result<WeatherInfo, Error>) -> Void) {

        guard !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" else {
            // Return mock data for demo
            let mockWeather = WeatherInfo(
                temperature: 72,
                high: 78,
                low: 65,
                condition: "Partly Cloudy",
                symbolName: "cloud.sun.fill",
                dayName: currentDayName()
            )
            DispatchQueue.main.async {
                completion(.success(mockWeather))
            }
            return
        }

        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "WeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                let temperature = Int(round(weatherData.main.temp))
                let high = Int(round(weatherData.main.tempMax))
                let low = Int(round(weatherData.main.tempMin))
                let condition = weatherData.weather.first?.description.capitalized ?? "Unknown"
                let weatherId = weatherData.weather.first?.id ?? 800
                let symbolName = self.weatherSymbol(for: weatherId)

                print("🌡️ Weather data received:")
                print("   Temperature: \(temperature)°F (raw: \(weatherData.main.temp))")
                print("   High: \(high)°F, Low: \(low)°F")
                print("   Condition: \(condition)")

                let weatherInfo = WeatherInfo(
                    temperature: temperature,
                    high: high,
                    low: low,
                    condition: condition,
                    symbolName: symbolName,
                    dayName: self.currentDayName()
                )

                DispatchQueue.main.async {
                    completion(.success(weatherInfo))
                }
            } catch {
                print("❌ Weather decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func currentDayName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full day name
        return formatter.string(from: Date())
    }

    private func weatherSymbol(for conditionId: Int) -> String {
        // OpenWeather condition codes: https://openweathermap.org/weather-conditions
        switch conditionId {
        case 200...232: // Thunderstorm
            return "cloud.bolt.rain.fill"
        case 300...321: // Drizzle
            return "cloud.drizzle.fill"
        case 500...531: // Rain
            return "cloud.rain.fill"
        case 600...622: // Snow
            return "cloud.snow.fill"
        case 701...781: // Atmosphere (fog, mist, etc.)
            return "cloud.fog.fill"
        case 800: // Clear
            return "sun.max.fill"
        case 801: // Few clouds
            return "cloud.sun.fill"
        case 802...804: // Clouds
            return "cloud.fill"
        default:
            return "cloud.fill"
        }
    }
}
