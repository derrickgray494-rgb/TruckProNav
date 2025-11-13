# RevenueCat Offerings Not Loading - Troubleshooting Checklist

## Problem
Paywall shows but no subscription packages are visible.

## Root Cause
RevenueCat can't fetch products from Apple's servers.

---

## ✅ App Store Connect Checklist

### 1. Paid Apps Agreement ⭐ MOST IMPORTANT
- [ ] Go to: App Store Connect → Agreements, Tax, and Banking
- [ ] "Paid Apps Agreement" status = **Active/In Effect**
- [ ] Banking info filled out
- [ ] Tax forms submitted

**Without this, Apple won't serve IAP data at all!**

---

### 2. In-App Purchase Products

Go to: App Store Connect → Your App → Monetization → In-App Purchases

For EACH product (`pro_weekly1`, `pro_monthly1`, `pro_yearly1`):

- [ ] Status shows **"Ready for Sale"** (not "Missing Metadata")
- [ ] Product ID matches exactly: `pro_weekly1`, `pro_monthly1`, `pro_yearly1`
- [ ] Pricing set for at least USA
- [ ] Display name filled in
- [ ] Description filled in
- [ ] **At least 1 screenshot uploaded** (can be placeholder)

**Common Issue:** "Missing Metadata" = incomplete configuration

---

### 3. App Itself in App Store Connect

- [ ] App status: Any status is OK (even "Prepare for Submission")
- [ ] Bundle ID matches: `com.trucknav.pro`
- [ ] At least one build uploaded (can be any build)

---

## ✅ RevenueCat Dashboard Checklist

### 1. Project Configuration
- [ ] API Key in app matches dashboard (in Info.plist): `appl_IbKfZxaIBJqapJwVjsUwLKOLDsk`
- [ ] iOS app bundle ID added: `com.trucknav.pro`
- [ ] App Store Connect integration linked

### 2. Products
Go to: RevenueCat → Products

- [ ] All 3 products exist:
  - `pro_weekly1`
  - `pro_monthly1`
  - `pro_yearly1`
- [ ] Products are **NOT** in sandbox-only mode
- [ ] Product IDs match App Store Connect exactly

### 3. Entitlements
Go to: RevenueCat → Entitlements

- [ ] Entitlement exists (e.g., "pro")
- [ ] All 3 products linked to the entitlement
- [ ] Entitlement identifier matches code: `pro` (or as defined in RevenueCatService.swift)

### 4. Offerings ⭐ CRITICAL
Go to: RevenueCat → Offerings

- [ ] At least one offering exists
- [ ] Offering identifier: `default` (or any name)
- [ ] **Offering is marked as "Current"** ← THIS IS THE ISSUE 90% OF THE TIME
- [ ] Offering contains packages:
  - Weekly package → `pro_weekly1`
  - Monthly package → `pro_monthly1`
  - Yearly package → `pro_yearly1`

**If "Current" is NOT enabled, offerings will be empty!**

---

## ✅ Testing Setup

### Option A: Sandbox Account (Recommended for Simulator)

1. **Create Sandbox Tester:**
   - App Store Connect → Users and Access → Sandbox Testers
   - Add new tester with fake email: `test@trucknav.test`
   - No need for real email verification

2. **Sign Out on Device/Simulator:**
   - Settings → iTunes & App Store → Sign Out
   - Or use fresh simulator without Apple ID

3. **Test Purchase:**
   - Run app, go to paywall
   - Tap subscribe
   - Sign in with sandbox account when prompted
   - Purchase should work with $0.00 charge

### Option B: StoreKit Configuration (Local Testing Only)

1. **Add to Xcode Scheme:**
   - Product → Scheme → Edit Scheme
   - Run → Options
   - StoreKit Configuration: Select `TruckNavPro.storekit`

2. **Note:** This only works for local testing, not real App Store validation

---

## 🔍 Debugging Steps

### 1. Check Xcode Console Logs

When paywall loads, look for these messages:

```
✅ GOOD:
🔄 Starting to load offerings from RevenueCat...
✅ Offerings loaded successfully
📦 Total offerings: 1
📦 Current offering: default
📦 Available packages count: 3
➕ Adding package 1: TruckNav Pro Weekly - $4.99

❌ BAD:
📦 Total offerings: 0
📦 Current offering: not set
📦 Available packages count: 0
```

### 2. Check RevenueCat Debug Logs

In `RevenueCatService.swift`, log level is set to `.debug`. Look for:
- `Purchases.logLevel = .debug` (line 91)
- Check console for RevenueCat API errors

### 3. Test API Connection

In Xcode console, after app launches, check for:
- `✅ RevenueCat configured`
- `✅ RevenueCat user logged in: [user_id]`

If missing, RevenueCat isn't initializing properly.

---

## 🚨 Common Errors & Solutions

### Error: "No current offering set in RevenueCat"
**Cause:** Offering exists but not marked as "Current"
**Fix:** RevenueCat dashboard → Offerings → Toggle "Current" ON

### Error: "No subscription packages available"
**Cause:** No packages added to offering
**Fix:** RevenueCat dashboard → Offerings → Add packages (weekly, monthly, yearly)

### Error: "Unable to load subscription options"
**Cause:** Network error or API key invalid
**Fix:**
- Check internet connection
- Verify API key in Info.plist matches dashboard
- Wait 10-15 minutes for changes to propagate

### Error: "Missing Metadata" in App Store Connect
**Cause:** Product incomplete
**Fix:** Add screenshot, description, pricing for product

### Products Load in Production but NOT in Development
**Cause:** Paid Apps Agreement or banking info incomplete
**Fix:** Complete all agreements in App Store Connect

---

## 📱 Quick Test

Run this in your app to verify RevenueCat connection:

```swift
Task {
    do {
        let offerings = try await RevenueCatService.shared.getOfferings()
        print("✅ Offerings: \(offerings.all.count)")
        print("✅ Current: \(offerings.current?.identifier ?? "none")")
        if let current = offerings.current {
            print("✅ Packages: \(current.availablePackages.count)")
        }
    } catch {
        print("❌ Error: \(error)")
    }
}
```

---

## 🎯 Most Likely Issues (In Order)

1. **Offering not marked as "Current"** (80% of cases)
2. **Products not "Ready for Sale"** in App Store Connect (15% of cases)
3. **Paid Apps Agreement not signed** (3% of cases)
4. **Product IDs don't match** between ASC and RevenueCat (2% of cases)

---

## ⏱️ Propagation Time

After making changes in RevenueCat or App Store Connect:
- **RevenueCat:** 5-15 minutes
- **App Store Connect:** 1-24 hours (usually instant for IAP)

**Always wait at least 10 minutes before testing again!**

---

## 📞 Still Not Working?

1. Share Xcode console output (look for the emoji logs I added)
2. Screenshot of RevenueCat Offerings page
3. Screenshot of App Store Connect IAP product status

The logs will tell us exactly what's wrong!
