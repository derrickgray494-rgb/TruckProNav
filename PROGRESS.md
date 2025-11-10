# TruckNavPro - Progress & Changes Log

## Session Date: November 10, 2025

---

## Summary

This document tracks all progress, changes, and recommended service providers for TruckNavPro development.

---

## Latest Update

**November 10, 2025 - Weather Radar Overlay Implemented**
- Added RainViewer API integration for live precipitation radar
- Weather overlay toggle in settings (Map Display section)
- Real-time weather visualization on navigation map
- 60% opacity for optimal visibility with map features

---

## Recent Changes

### 1. Bridge Hazard Warning System (Completed)
**Date:** November 10, 2025

**Problem:** App only avoided truck restrictions via routing but didn't warn drivers about specific hazards (bridge clearances, weight limits, etc.)

**Solution:** Implemented comprehensive hazard warning system using OpenStreetMap integration

**Changes Made:**
- **OpenStreetMapService.swift** (NEW)
  - Integrates OSM Overpass API for truck restriction queries
  - Parses maxheight, maxweight, maxwidth, maxlength tags
  - Samples route coordinates every 500m to reduce API load
  - Handles multiple unit formats (feet, meters, tons, pounds)

- **HazardMonitoringService.swift** (NEW)
  - Monitors route for hazards during navigation
  - Checks every 5 seconds and when location changes >100m
  - Compares truck dimensions vs restrictions with safety margins
  - Respects user settings for warning distance (default 1.5 miles)
  - Caches restrictions for entire route on navigation start

- **HazardWarningView.swift** (NEW)
  - Displays calm, factual hazard warnings (per driver feedback)
  - Orange/yellow backgrounds instead of aggressive red
  - Shows specific measurements and clearance calculations
  - Soft notification chime (not alarm/vibration)
  - User-dismissible warnings

- **TruckSettings.swift** (MODIFIED)
  - Added `enableHazardWarnings` (Bool, default: true)
  - Added `enableHazardAudio` (Bool, default: true)
  - Added `warningDistance` (Double, default: 2400m/1.5 miles)
  - Added `length` property for truck length restrictions

- **SettingsViewController.swift** (MODIFIED)
  - New "Hazard Warnings" section with toggles
  - Enable/disable warnings
  - Enable/disable audio alerts

- **NavigationViewController.swift** (MODIFIED)
  - Integrated hazard monitoring service
  - Plays soft notification chime when hazard detected
  - Displays hazard warnings during navigation
  - Respects user settings for warnings

**Key Design Decision:**
User (who is an actual truck driver) requested calm, factual warnings:
> "i dont want to scare users ('STOP, Bridge too low), the calm approach is better so user will surely be notified but they still make their own choice(human nature). so yes go with osm integration but dont be so aggresive in the warning tones, as a truck driver myself its already a stressful situation"

**Result:**
- Warnings show facts: "Note: 6\" over clearance" instead of "UNSAFE - DO NOT PROCEED"
- Driver retains decision-making control
- Professional, stress-reducing UX

---

### 2. US Measurements Only (Completed)
**Date:** November 10, 2025

**Problem:** Settings displayed both imperial and metric units (e.g., "13'6\" (4.11m)"), user wanted US measurements only

**Solution:** Updated all display and input methods to use exclusively US units

**Changes Made:**
- **TruckSettings.swift** (MODIFIED)
  - `formattedHeight()` now returns only "13'6\"" (removed metric)
  - `formattedWidth()` now returns only "10'" (removed metric)
  - `formattedWeight()` now returns only "80,000 lbs" (removed metric)
  - Fixed bug in width formatting (was using height value)

- **SettingsViewController.swift** (MODIFIED)
  - Input dialogs now accept US measurements (feet, pounds)
  - Converts to metric for internal storage
  - Height input: feet (e.g., 13.5 for 13'6\")
  - Width input: feet (e.g., 8.0)
  - Weight input: pounds (e.g., 80000)

**Internal Storage:** Still uses metric (meters/tons) for calculations and API compatibility

**Display:** Shows only US units as requested

---

### 3. Weather Radar Overlay (Completed)
**Date:** November 10, 2025

**User Request:** "is it possible to add weather overlays to reflect that it is snowing or whatever condition can the main mapscreen reflect this"

**Solution:** Implemented live weather radar using RainViewer API

**Changes Made:**
- **WeatherOverlayService.swift** (NEW)
  - Fetches live weather data from RainViewer API
  - Creates Mapbox RasterSource for weather tiles
  - Adds/removes weather layer dynamically
  - 60% opacity for optimal map visibility
  - Positioned below labels, above roads
  - Supports animated radar (future enhancement)

- **TruckSettings.swift** (MODIFIED)
  - Added `showWeatherOverlay` (Bool, default: false)
  - Persists weather overlay preference

- **SettingsViewController.swift** (MODIFIED)
  - Added "Show Weather Radar" toggle in Map Display section
  - Row 3 in Map section
  - Tag 2003 for switch handling

- **NavigationViewController.swift** (MODIFIED)
  - Added `weatherOverlayService` property
  - Initialized weather service on startup
  - Calls `updateWeatherOverlay()` on style load
  - Updates overlay when settings change
  - Dynamic add/remove based on toggle

**Technical Details:**
- **API:** RainViewer (https://api.rainviewer.com/public/weather-maps.json)
- **Cost:** FREE
- **Format:** Raster tile overlay (256x256 PNG tiles)
- **Data:** Past radar + nowcast (up to 30 min future)
- **Tile URL:** `{host}{path}/256/{z}/{x}/{y}/6/1_1.png`
- **Coverage:** Global precipitation radar
- **Update:** Fetched on demand when overlay enabled

**User Experience:**
- Toggle on/off in settings
- Overlay appears immediately when enabled
- Shows rain, snow, and precipitation intensity
- Color-coded radar imagery
- Transparent enough to see map underneath
- Works during navigation and free-drive mode

---

## Recommended Service Providers

### 1. Routing & Navigation
**Provider:** TomTom Routing API
- **Status:** ACTIVE
- **Purpose:** Truck-specific routing with dimension avoidance
- **Endpoint:** https://api.tomtom.com/routing/1/calculateRoute
- **Features:**
  - Truck routing mode
  - Vehicle dimensions (height, weight, width, length)
  - Avoidances (tolls, highways, ferries, tunnels)
  - Hazmat load restrictions
  - Live traffic integration
- **API Key:** Required (currently integrated)
- **Pricing:** Pay per request
- **Documentation:** https://developer.tomtom.com/routing-api/documentation

### 2. Truck Restrictions Data
**Provider:** OpenStreetMap (Overpass API)
- **Status:** ACTIVE
- **Purpose:** Real-time truck restriction queries (bridge heights, weight limits)
- **Endpoint:** https://overpass-api.de/api/interpreter
- **Features:**
  - FREE service
  - Global coverage
  - Community-maintained data
  - maxheight, maxweight, maxwidth, maxlength tags
  - Road names and coordinates
- **Rate Limits:** Fair use policy, avoid excessive queries
- **Data Quality:** Varies by region (excellent in US/Europe)
- **Documentation:** https://wiki.openstreetmap.org/wiki/Overpass_API

### 3. Weather Overlay
**Provider:** RainViewer API
- **Status:** ACTIVE (Implemented November 10, 2025)
- **Purpose:** Live weather radar overlay (precipitation, snow, rain)
- **Endpoint:** https://api.rainviewer.com/public/weather-maps.json
- **Features:**
  - FREE tier (currently using)
  - Real-time precipitation radar
  - Historical data (2 hours)
  - Future forecasts (30 minutes)
  - Tile-based overlay system
  - Mapbox RasterSource integration
- **Integration:** WeatherOverlayService with custom RasterSource/RasterLayer
- **Pricing:** Free for basic use, paid tiers for high volume
- **Documentation:** https://www.rainviewer.com/api.html
- **Alternative:** OpenWeatherMap (paid, more features)

### 4. Maps & Geocoding
**Provider:** Mapbox
- **Status:** ACTIVE
- **Purpose:** Base maps, navigation UI, search, geocoding
- **SDK:** Mapbox Navigation iOS SDK v3
- **Features:**
  - NavigationMapView
  - Turn-by-turn navigation
  - Custom map styles (day/night)
  - POI search
  - Geocoding
- **API Key:** Required (currently integrated)
- **Pricing:** Pay per monthly active user
- **Documentation:** https://docs.mapbox.com/ios/navigation/

### 5. Subscription Management
**Provider:** RevenueCat
- **Status:** ACTIVE
- **Purpose:** In-app subscription management and paywalls
- **Features:**
  - iOS StoreKit integration
  - Subscription analytics
  - Paywall templates
  - Cross-platform support
  - Server-side receipt validation
- **Products Configured:**
  - Weekly: $3.99/week (3-day trial)
  - Monthly: $14.99/month (7-day trial)
  - Yearly: $99/year (7-day trial)
- **Model:** "Subscribe or bye" (mandatory subscription)
- **API Key:** Required (currently integrated)
- **Pricing:** Free tier available, % of revenue for paid tiers
- **Documentation:** https://www.revenuecat.com/docs

### 6. Backend Services
**Provider:** Supabase
- **Status:** INTEGRATED (not heavily used yet)
- **Purpose:** Backend database, auth, storage
- **Features:**
  - PostgreSQL database
  - User authentication
  - Real-time subscriptions
  - File storage
  - Edge functions
- **Pricing:** Free tier available
- **Documentation:** https://supabase.com/docs

---

## Future Recommendations

### 1. Traffic Incidents & Alerts
**Provider:** TomTom Traffic API
- **Purpose:** Real-time traffic incidents, road closures, construction
- **Status:** Available but not implemented
- **Use Case:** Warn drivers of accidents, delays ahead
- **Documentation:** https://developer.tomtom.com/traffic-api

### 2. Truck Parking
**Provider:** Trucker Path API or custom OSM queries
- **Purpose:** Find truck stops, rest areas, parking
- **Status:** Not implemented
- **Use Case:** Help drivers find safe parking

### 3. Weigh Station Alerts
**Provider:** Custom database or crowd-sourced data
- **Purpose:** Alert drivers of upcoming weigh stations
- **Status:** Not implemented
- **Use Case:** Compliance and planning

### 4. Fuel Prices
**Provider:** GasBuddy API or OPIS
- **Purpose:** Show fuel prices at truck stops
- **Status:** Not implemented
- **Use Case:** Cost optimization

---

## Build & Deployment Status

### TestFlight
- **Latest Build:** 1.0 (2)
- **Status:** Waiting for Beta App Review approval
- **External Testing:** Configured
- **Test Groups:** Set up

### App Store Requirements
- **Privacy Policy:** ✅ Completed
- **Support Documentation:** ✅ Completed
- **Copyright:** Required for submission
- **Screenshots:** Pending
- **App Description:** Pending

---

## Technical Stack

### Languages & Frameworks
- Swift 5.x
- UIKit
- CoreLocation
- MapKit (supplementary)

### Dependencies (via SPM)
- Mapbox Navigation iOS SDK v3.16.1
- RevenueCat SDK v5.47.0
- Supabase Swift v2.37.0

### Architecture
- MVC pattern
- Service-oriented architecture
- UserDefaults for settings persistence
- Delegate pattern for view coordination

---

## Performance Optimizations

### OSM Query Optimization
- Sample coordinates every 500m (not every point)
- Cache restrictions for entire route
- Single API call per route start
- Fair use compliance

### Hazard Monitoring
- Check every 5 seconds (not continuous)
- Only check when moved >100m
- Pre-filter restrictions within 2km ahead
- Single hazard display at a time

---

## UX Design Principles

### Hazard Warnings
1. **Calm over Alarming:** Orange/yellow instead of red
2. **Facts over Fear:** Show numbers, let driver decide
3. **Soft Alerts:** Notification chime, not alarm
4. **Driver Control:** Dismissible warnings
5. **Professional:** Respect driver expertise

### Settings
1. **US Measurements:** Feet, inches, pounds (not metric)
2. **Truck Defaults:** 13'6\" height, 8' width, 53' length, 80,000 lbs
3. **Clear Labels:** Explicit descriptions
4. **Easy Input:** Simple numeric entry with examples

---

## Known Issues & Future Work

### Pending
- [ ] Alternative route selection in preview mode
- [ ] Camera auto-follow smoothness tuning
- [ ] Route preview ETA details display improvement
- [ ] Weather radar animation (frame cycling)
- [ ] Weather overlay opacity adjustment slider

### Completed (November 10, 2025)
- [✅] Bridge hazard warnings with OSM
- [✅] Hazard warning toggles in settings
- [✅] US measurements only (no dual units)
- [✅] Truck length property added
- [✅] Calm warning tone implementation
- [✅] Traffic overlay on map (Mapbox traffic layer)
- [✅] Weather radar overlay (RainViewer API)
- [✅] Input dialogs accept US measurements (feet, pounds)

---

## Contact & Support

**Developer:** Solo indie developer
**Feedback:** GitHub Issues
**Support:** In-app support documentation

---

**Last Updated:** November 10, 2025
**Version:** 1.0 (Build 2+)
**Platform:** iOS 17.0+
