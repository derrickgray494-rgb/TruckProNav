# TruckNav Pro - Backend Integration Setup Guide

Complete guide to integrating Supabase and RevenueCat into TruckNav Pro.

---

## 📋 Table of Contents

1. [Swift Package Dependencies](#1-swift-package-dependencies)
2. [Supabase Setup](#2-supabase-setup)
3. [RevenueCat Setup](#3-revenuecat-setup)
4. [Configuration](#4-configuration)
5. [Testing](#5-testing)

---

## 1. Swift Package Dependencies

### Add Supabase SDK

1. Open TrucknavPro.xcodeproj in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter URL: `https://github.com/supabase/supabase-swift`
4. Select **Up to Next Major Version**: `2.0.0`
5. Click **Add Package**
6. Select the following products:
   - **Supabase**
   - **Auth**
   - **PostgREST**
   - **Realtime**
   - **Storage**
7. Click **Add Package**

### Add RevenueCat SDK

1. Go to **File → Add Package Dependencies...**
2. Enter URL: `https://github.com/RevenueCat/purchases-ios`
3. Select **Up to Next Major Version**: `4.0.0`
4. Click **Add Package**
5. Select **RevenueCat**
6. Click **Add Package**

---

## 2. Supabase Setup

### A. Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Click **New Project**
3. Fill in project details:
   - **Name**: TruckNav Pro
   - **Database Password**: (create a strong password)
   - **Region**: Choose closest to your users
4. Click **Create new project**

### B. Set Up Database Schema

1. Wait for project initialization (2-3 minutes)
2. Go to **SQL Editor** in the left sidebar
3. Click **New query**
4. Copy the entire contents of `SUPABASE_SCHEMA.sql`
5. Paste into the SQL editor
6. Click **Run** (or press Cmd+Enter)
7. Verify all tables were created successfully

### C. Get API Credentials

1. Go to **Settings → API** in your Supabase dashboard
2. Copy the following values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbGciOiJIUzI1N...`

### D. Configure Authentication

1. Go to **Authentication → Providers**
2. Enable **Email** provider (enabled by default)
3. Enable **Apple** provider:
   - Click **Apple**
   - Toggle **Enable Sign in with Apple**
   - Follow Apple setup instructions (requires Apple Developer account)
4. Configure **Email Templates** (optional):
   - Go to **Authentication → Email Templates**
   - Customize signup confirmation email
   - Customize password reset email

---

## 3. RevenueCat Setup

### A. Create RevenueCat Account

1. Go to [https://www.revenuecat.com](https://www.revenuecat.com)
2. Sign up for a free account
3. Click **Create new project**
4. Name: **TruckNav Pro**
5. Select platform: **iOS**

### B. Create Products

1. Go to **Products** in the left sidebar
2. Click **+ New**
3. Create **Pro Monthly**:
   - Identifier: `pro_monthly`
   - Type: Auto-renewable subscription
   - Duration: 1 month
4. Create **Premium Yearly**:
   - Identifier: `premium_yearly`
   - Type: Auto-renewable subscription
   - Duration: 1 year

### C. Create Entitlements

1. Go to **Entitlements** in the left sidebar
2. Click **+ New entitlement**
3. Create **Pro** entitlement:
   - Identifier: `pro`
   - Attach product: `pro_monthly`
4. Create **Premium** entitlement:
   - Identifier: `premium`
   - Attach products: `pro_monthly`, `premium_yearly`

### D. Configure App Store Connect

1. Go to **App Store Connect**:
   - Create your app if not already created
   - Go to **Features → In-App Purchases**
   - Create subscription group: "TruckNav Pro Subscriptions"
   - Create subscriptions matching RevenueCat products:
     - **Pro Monthly**: $9.99/month
     - **Premium Yearly**: $79.99/year

2. In RevenueCat dashboard:
   - Go to **Apps → iOS**
   - Click **Configure**
   - Enter your App Store Connect credentials
   - Link subscription products

### E. Get API Key

1. Go to **Settings → API Keys**
2. Copy your **Public API Key**: `appl_xxxxx`

---

## 4. Configuration

### A. Update Info.plist

1. Open `TrucknavPro/Info.plist`
2. Add Supabase credentials:

```xml
<!-- Supabase Configuration -->
<key>SupabaseURL</key>
<string>https://xxxxx.supabase.co</string>
<key>SupabaseAnonKey</key>
<string>eyJhbGciOiJIUzI1N...</string>

<!-- RevenueCat Configuration -->
<key>RevenueCatAPIKey</key>
<string>appl_xxxxx</string>
```

Replace the values with your actual credentials from steps 2C and 3E.

### B. Initialize Services

The services are already initialized automatically:
- `SupabaseService.shared` initializes on first access
- `RevenueCatService.shared` initializes on first access

To manually initialize in AppDelegate (optional):

```swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialize backend services
        _ = SupabaseService.shared
        RevenueCatService.shared.configure()

        return true
    }
}
```

---

## 5. Testing

### Test Supabase Connection

```swift
Task {
    do {
        // Test sign up
        let user = try await SupabaseService.shared.signUp(
            email: "test@example.com",
            password: "password123"
        )
        print("✅ User created: \(user.id)")

        // Test profile creation
        let profile = UserProfile(
            id: user.id.uuidString,
            email: user.email,
            fullName: "Test User",
            avatarUrl: nil,
            createdAt: Date()
        )
        try await SupabaseService.shared.saveUserProfile(
            userId: user.id.uuidString,
            profile: profile
        )
        print("✅ Profile saved")

    } catch {
        print("❌ Error: \(error)")
    }
}
```

### Test RevenueCat

```swift
Task {
    do {
        let offerings = try await RevenueCatService.shared.getOfferings()
        print("✅ Offerings loaded: \(offerings.all.count)")

        // Check subscription status
        let customerInfo = try await RevenueCatService.shared.getCustomerInfo()
        print("✅ Current tier: \(RevenueCatService.shared.currentTier.displayName)")

    } catch {
        print("❌ Error: \(error)")
    }
}
```

### Test Sandbox Purchases

1. Go to **Settings → App Store → Sandbox Account**
2. Sign in with test account (create in App Store Connect)
3. Run the app
4. Trigger paywall: `RevenueCatService.shared.showPaywall(from: self)`
5. Make a sandbox purchase
6. Verify entitlements are granted

---

## 6. Features Implementation

### Show Paywall for Locked Features

```swift
// In your view controller
func handleFeatureAccess() {
    // Check if user has access to unlimited routes
    if RevenueCatService.shared.checkFeatureAccess(
        feature: .unlimitedRoutes,
        from: self
    ) {
        // User has access, proceed
        saveRoute()
    } else {
        // Paywall will be shown automatically
        // User needs to upgrade
    }
}
```

### Save User Data to Supabase

```swift
// Save a route
Task {
    guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
        return
    }

    let route = SavedRoute(
        id: nil,
        userId: userId,
        name: "Route to Chicago",
        startLatitude: 41.8781,
        startLongitude: -87.6298,
        endLatitude: 42.3601,
        endLongitude: -71.0589,
        distance: 1500.0,
        duration: 18000.0,
        createdAt: Date()
    )

    try await SupabaseService.shared.saveRoute(route)
}
```

---

## 7. Next Steps

✅ All backend services are implemented and ready to use!

**Recommended next steps:**
1. Create authentication UI (login/signup screens)
2. Add user profile screen
3. Implement saved routes list
4. Add favorites management
5. Create trip history view
6. Test subscription flows end-to-end

---

## 📚 Documentation

- [Supabase Swift Documentation](https://supabase.com/docs/reference/swift)
- [RevenueCat iOS Documentation](https://www.revenuecat.com/docs/getting-started/installation/ios)
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)

---

## 🆘 Troubleshooting

### Supabase Connection Issues

- Verify URL and anon key are correct
- Check Row Level Security policies are enabled
- Ensure user is authenticated before accessing protected tables

### RevenueCat Issues

- Verify API key is correct
- Check products are properly linked in RevenueCat dashboard
- Use sandbox tester account for testing
- Clear app data and reinstall if needed

### Build Errors

- Clean build folder: **Product → Clean Build Folder**
- Delete derived data: `~/Library/Developer/Xcode/DerivedData`
- Re-add Swift packages if needed

---

**Setup complete! Your backend is ready to go! 🚀**
