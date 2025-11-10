//
//  SupabaseService.swift
//  TruckNavPro
//

import Foundation
import Supabase

class SupabaseService {

    static let shared = SupabaseService()

    private var client: SupabaseClient!

    // Current user
    var currentUser: User? {
        get async {
            return try? await client.auth.session.user
        }
    }

    private init() {
        // Load Supabase credentials from Info.plist
        guard let supabaseURL = Bundle.main.infoDictionary?["SupabaseURL"] as? String,
              let supabaseKey = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String,
              let url = URL(string: supabaseURL) else {
            print("⚠️ Supabase credentials not configured in Info.plist")
            return
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseKey)
        print("✅ Supabase client initialized")
    }

    // MARK: - Authentication

    /// Sign up a new user with email and password
    func signUp(email: String, password: String) async throws -> User {
        let response = try await client.auth.signUp(email: email, password: password)
        print("✅ User signed up: \(response.user.email ?? "unknown")")
        return response.user
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> Session {
        let session = try await client.auth.signIn(email: email, password: password)
        print("✅ User signed in: \(session.user.email ?? "unknown")")
        return session
    }

    /// Sign in with Apple
    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        print("✅ User signed in with Apple: \(session.user.email ?? "unknown")")
        return session
    }

    /// Sign out current user
    func signOut() async throws {
        try await client.auth.signOut()
        print("✅ User signed out")
    }

    /// Get current session
    func getCurrentSession() async throws -> Session {
        return try await client.auth.session
    }

    // MARK: - User Profile

    /// Create or update user profile
    func saveUserProfile(userId: String, profile: UserProfile) async throws {
        try await client.database
            .from("profiles")
            .upsert(profile)
            .execute()
        print("✅ User profile saved")
    }

    /// Get user profile
    func getUserProfile(userId: String) async throws -> UserProfile {
        let response: [UserProfile] = try await client.database
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value

        guard let profile = response.first else {
            throw NSError(domain: "SupabaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }

        return profile
    }

    // MARK: - Saved Routes

    /// Save a route to the database
    func saveRoute(_ route: SavedRoute) async throws {
        try await client.database
            .from("saved_routes")
            .insert(route)
            .execute()
        print("✅ Route saved: \(route.name)")
    }

    /// Get all saved routes for current user
    func getSavedRoutes(userId: String) async throws -> [SavedRoute] {
        let routes: [SavedRoute] = try await client.database
            .from("saved_routes")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("✅ Fetched \(routes.count) saved routes")
        return routes
    }

    /// Delete a saved route
    func deleteRoute(routeId: String) async throws {
        try await client.database
            .from("saved_routes")
            .delete()
            .eq("id", value: routeId)
            .execute()
        print("✅ Route deleted")
    }

    // MARK: - Favorite Locations

    /// Save a favorite location
    func saveFavorite(_ favorite: FavoriteLocation) async throws {
        try await client.database
            .from("favorites")
            .insert(favorite)
            .execute()
        print("✅ Favorite saved: \(favorite.name)")
    }

    /// Get all favorites for current user
    func getFavorites(userId: String) async throws -> [FavoriteLocation] {
        let favorites: [FavoriteLocation] = try await client.database
            .from("favorites")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("✅ Fetched \(favorites.count) favorites")
        return favorites
    }

    /// Delete a favorite location
    func deleteFavorite(favoriteId: String) async throws {
        try await client.database
            .from("favorites")
            .delete()
            .eq("id", value: favoriteId)
            .execute()
        print("✅ Favorite deleted")
    }

    // MARK: - Trip History

    /// Save trip history
    func saveTripHistory(_ trip: TripHistory) async throws {
        try await client.database
            .from("trip_history")
            .insert(trip)
            .execute()
        print("✅ Trip history saved")
    }

    /// Get trip history for current user
    func getTripHistory(userId: String, limit: Int = 50) async throws -> [TripHistory] {
        let trips: [TripHistory] = try await client.database
            .from("trip_history")
            .select()
            .eq("user_id", value: userId)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        print("✅ Fetched \(trips.count) trips")
        return trips
    }

    // MARK: - Truck Settings

    /// Save truck configuration
    func saveTruckSettings(_ settings: DatabaseTruckSettings) async throws {
        try await client.database
            .from("truck_settings")
            .upsert(settings)
            .execute()
        print("✅ Truck settings saved")
    }

    /// Get truck settings for current user
    func getTruckSettings(userId: String) async throws -> DatabaseTruckSettings? {
        let settings: [DatabaseTruckSettings] = try await client.database
            .from("truck_settings")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        return settings.first
    }
}

// MARK: - Data Models

struct UserProfile: Codable {
    let id: String
    let email: String?
    let fullName: String?
    let avatarUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct SavedRoute: Codable {
    let id: String?
    let userId: String
    let name: String
    let startLatitude: Double
    let startLongitude: Double
    let endLatitude: Double
    let endLongitude: Double
    let distance: Double
    let duration: Double
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case startLatitude = "start_latitude"
        case startLongitude = "start_longitude"
        case endLatitude = "end_latitude"
        case endLongitude = "end_longitude"
        case distance
        case duration
        case createdAt = "created_at"
    }
}

struct FavoriteLocation: Codable {
    let id: String?
    let userId: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let category: String?
    let notes: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case address
        case latitude
        case longitude
        case category
        case notes
        case createdAt = "created_at"
    }
}

struct TripHistory: Codable {
    let id: String?
    let userId: String
    let startLatitude: Double
    let startLongitude: Double
    let endLatitude: Double
    let endLongitude: Double
    let distance: Double
    let duration: Double
    let startedAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startLatitude = "start_latitude"
        case startLongitude = "start_longitude"
        case endLatitude = "end_latitude"
        case endLongitude = "end_longitude"
        case distance
        case duration
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct DatabaseTruckSettings: Codable {
    let userId: String
    let height: Double  // meters
    let width: Double   // meters
    let weight: Double  // metric tons
    let length: Double  // meters
    let hazmat: Bool
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case height
        case width
        case weight
        case length
        case hazmat
        case updatedAt = "updated_at"
    }
}
