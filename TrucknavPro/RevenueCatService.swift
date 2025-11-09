//
//  RevenueCatService.swift
//  TruckNavPro
//

import Foundation
import RevenueCat

// MARK: - Subscription Tiers

enum SubscriptionTier: String {
    case free = "free"
    case pro = "pro_monthly"
    case premium = "premium_yearly"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .premium: return "Premium"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Basic navigation",
                "TomTom truck routing",
                "Weather widget",
                "Up to 5 saved routes"
            ]
        case .pro:
            return [
                "All Free features",
                "Unlimited saved routes",
                "Offline maps",
                "Advanced truck settings",
                "Traffic alerts",
                "Trip history (30 days)"
            ]
        case .premium:
            return [
                "All Pro features",
                "Lifetime trip history",
                "Priority support",
                "Custom truck profiles",
                "Fleet management tools",
                "Ad-free experience"
            ]
        }
    }
}

// MARK: - RevenueCat Service

class RevenueCatService {

    static let shared = RevenueCatService()

    // Current subscription tier
    private(set) var currentTier: SubscriptionTier = .free

    // Active entitlements
    private(set) var activeEntitlements: Set<String> = []

    private init() {
        configure()
    }

    // MARK: - Configuration

    func configure() {
        // Load RevenueCat API key from Info.plist
        guard let apiKey = Bundle.main.infoDictionary?["RevenueCatAPIKey"] as? String else {
            print("⚠️ RevenueCat API key not found in Info.plist")
            return
        }

        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)

        // Set user ID if logged in
        if let userId = SupabaseService.shared.currentUser?.id.uuidString {
            Purchases.shared.logIn(userId) { customerInfo, created, error in
                if let error = error {
                    print("❌ RevenueCat login error: \(error.localizedDescription)")
                } else {
                    print("✅ RevenueCat user logged in: \(userId)")
                    self.updateSubscriptionStatus(customerInfo: customerInfo)
                }
            }
        }

        print("✅ RevenueCat configured")
    }

    // MARK: - Subscription Management

    /// Get available packages/offerings
    func getOfferings() async throws -> Offerings {
        return try await Purchases.shared.offerings()
    }

    /// Purchase a package
    func purchase(package: Package) async throws -> (transaction: StoreTransaction?, customerInfo: CustomerInfo, userCancelled: Bool) {
        let result = try await Purchases.shared.purchase(package: package)
        updateSubscriptionStatus(customerInfo: result.customerInfo)
        print("✅ Purchase successful: \(package.storeProduct.localizedTitle)")
        return result
    }

    /// Restore purchases
    func restorePurchases() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateSubscriptionStatus(customerInfo: customerInfo)
        print("✅ Purchases restored")
        return customerInfo
    }

    /// Get current customer info
    func getCustomerInfo() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.customerInfo()
        updateSubscriptionStatus(customerInfo: customerInfo)
        return customerInfo
    }

    /// Update subscription status based on customer info
    private func updateSubscriptionStatus(customerInfo: CustomerInfo?) {
        guard let info = customerInfo else {
            currentTier = .free
            activeEntitlements = []
            return
        }

        // Update active entitlements
        activeEntitlements = Set(info.entitlements.active.keys)

        // Determine current tier
        if info.entitlements.active["premium"] != nil {
            currentTier = .premium
        } else if info.entitlements.active["pro"] != nil {
            currentTier = .pro
        } else {
            currentTier = .free
        }

        print("📱 Subscription updated: \(currentTier.displayName)")
        print("🎟️ Active entitlements: \(activeEntitlements)")

        // Post notification for UI updates
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }

    // MARK: - Feature Gating

    /// Check if user has access to a specific feature
    func hasAccess(to feature: Feature) -> Bool {
        switch feature {
        case .basicNavigation, .weather, .search:
            return true  // Available to all

        case .unlimitedRoutes, .offlineMaps, .advancedTruckSettings, .trafficAlerts:
            return currentTier == .pro || currentTier == .premium

        case .lifetimeHistory, .prioritySupport, .customProfiles, .fleetManagement:
            return currentTier == .premium
        }
    }

    /// Show paywall if feature is locked
    func checkFeatureAccess(feature: Feature, from viewController: UIViewController) -> Bool {
        if hasAccess(to: feature) {
            return true
        } else {
            showPaywall(from: viewController, feature: feature)
            return false
        }
    }

    /// Present paywall
    func showPaywall(from viewController: UIViewController, feature: Feature? = nil) {
        let paywallVC = PaywallViewController()
        paywallVC.requiredFeature = feature
        paywallVC.modalPresentationStyle = .fullScreen
        viewController.present(paywallVC, animated: true)
    }
}

// MARK: - Features

enum Feature {
    // Free tier
    case basicNavigation
    case weather
    case search

    // Pro tier
    case unlimitedRoutes
    case offlineMaps
    case advancedTruckSettings
    case trafficAlerts

    // Premium tier
    case lifetimeHistory
    case prioritySupport
    case customProfiles
    case fleetManagement

    var displayName: String {
        switch self {
        case .basicNavigation: return "Basic Navigation"
        case .weather: return "Weather Widget"
        case .search: return "Search"
        case .unlimitedRoutes: return "Unlimited Saved Routes"
        case .offlineMaps: return "Offline Maps"
        case .advancedTruckSettings: return "Advanced Truck Settings"
        case .trafficAlerts: return "Traffic Alerts"
        case .lifetimeHistory: return "Lifetime Trip History"
        case .prioritySupport: return "Priority Support"
        case .customProfiles: return "Custom Truck Profiles"
        case .fleetManagement: return "Fleet Management"
        }
    }

    var requiredTier: SubscriptionTier {
        switch self {
        case .basicNavigation, .weather, .search:
            return .free
        case .unlimitedRoutes, .offlineMaps, .advancedTruckSettings, .trafficAlerts:
            return .pro
        case .lifetimeHistory, .prioritySupport, .customProfiles, .fleetManagement:
            return .premium
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
