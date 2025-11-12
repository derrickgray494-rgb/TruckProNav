# TruckNavPro - Complete Features & Integrations Guide

**Last Updated:** January 12, 2025

---

## Overview

TruckNavPro is a professional-grade truck navigation app for iOS that provides truck-specific routing, live traffic, weather conditions, and multi-stop route optimization. Built with cutting-edge APIs and services, it delivers real-time navigation tailored specifically for commercial truck drivers.

---

## Core Integrations

### 1. HERE Technologies (Primary Navigation Provider)

**Services Used:**
- **HERE Routing API v8** - Truck-specific route calculation
- **HERE Traffic Flow API v7** - Real-time traffic congestion data
- **HERE Traffic Incidents API v7** - Live road incidents and hazards
- **HERE Waypoint Sequence API v8** - Multi-stop route optimization

**Key Features:**
- Truck-specific routing with vehicle dimensions (height, weight, width, length)
- Hazardous materials restrictions
- Bridge height clearance checks
- Weight limit validation
- Toll road avoidance
- Real-time traffic flow with jam factor (0-10 scale)
- Live incident reporting (accidents, road closures, construction)
- Intelligent waypoint optimization for delivery routes

**API Endpoints:**
```
Routing: https://router.hereapi.com/v8/routes
Traffic Flow: https://data.traffic.hereapi.com/v7/flow
Traffic Incidents: https://data.traffic.hereapi.com/v7/incidents
Waypoint Sequence: https://wps.hereapi.com/v8/findsequence2
```

**Configuration:**
- API Key required (stored in app configuration)
- Truck parameters: Dimensions in centimeters, weight in kg
- Returns polyline geometry, turn-by-turn instructions, tolls, and summaries

---

### 2. TomTom (Fallback Navigation Provider)

**Services Used:**
- **TomTom Routing API** - Backup truck routing
- **TomTom Traffic Flow API** - Fallback traffic data
- **TomTom Traffic Incidents API** - Backup incident data

**Key Features:**
- Automatic fallback when HERE services are unavailable
- Truck routing with vehicle profile
- Traffic congestion levels (0-3: Free Flow, Slow, Congestion, Heavy)
- Incident detection with severity ratings
- Seamless service switching

**API Endpoints:**
```
Routing: https://api.tomtom.com/routing/1/calculateRoute
Traffic Flow: https://api.tomtom.com/traffic/services/4/flowSegmentData
Traffic Incidents: https://api.tomtom.com/traffic/services/5/incidentDetails
```

**Fallback Strategy:**
1. Try HERE first (primary)
2. If HERE fails, automatically switch to TomTom
3. Log all fallback events for monitoring

---

### 3. Mapbox Maps & Navigation SDK v3

**Services Used:**
- **Mapbox Maps SDK** - Map rendering and display
- **Mapbox Navigation SDK v3** - Turn-by-turn navigation UI
- **Mapbox Directions API** - Route geometry for navigation

**Key Features:**
- High-performance map rendering
- Custom map styles
- Turn-by-turn voice guidance
- Route preview with alternatives
- Lane guidance
- Speed limit display
- Maneuver instructions
- Real-time puck positioning with compass rotation
- Alternative routes with visual comparison

**Components:**
- `NavigationMapView` - Main map display
- `NavigationViewController` - Full navigation UI
- `PointAnnotationManager` - Marker management for POIs, stops, incidents

---

### 4. Apple Weather & Location Services

**Services Used:**
- **WeatherKit** - Real-time weather data
- **Core Location** - GPS positioning and tracking
- **MapKit** - Search and geocoding

**Key Features:**
- Current weather conditions
- Weather radar overlay
- Temperature (Fahrenheit/Celsius toggle)
- Wind speed and direction
- Precipitation probability
- Weather alerts and warnings
- Location-based search
- Address geocoding
- Reverse geocoding for coordinates

**Weather Display:**
- Live temperature
- Weather icon (sunny, cloudy, rain, snow, etc.)
- Wind conditions
- Optional radar layer on map

---

### 5. RevenueCat (Subscription Management)

**Services Used:**
- **RevenueCat iOS SDK** - Subscription handling
- **StoreKit Integration** - Apple In-App Purchases

**Key Features:**
- Subscription paywall with multiple tiers
- Free tier with basic features
- Pro tier with advanced features
- Premium tier with all features
- Purchase restoration
- Receipt validation
- Cross-platform entitlement management

**Subscription Tiers:**

| Feature | Free | Pro | Premium |
|---------|------|-----|---------|
| Basic Navigation | ✅ | ✅ | ✅ |
| Truck Routing | ✅ | ✅ | ✅ |
| Live Traffic | ❌ | ✅ | ✅ |
| Weather Radar | ❌ | ✅ | ✅ |
| Multi-Stop Routing | ❌ | ✅ | ✅ |
| Route Optimization | ❌ | ❌ | ✅ |
| POI Import | ❌ | ❌ | ✅ |
| Offline Maps | ❌ | ❌ | ✅ |

**Paywall Configuration:**
- Apple Connect product setup
- RevenueCat offering configuration
- Error handling with fallback to first offering
- Detailed logging for debugging

---

### 6. OpenStreetMap Overpass API

**Services Used:**
- **Overpass API** - Truck restriction data

**Key Features:**
- Maxweight restrictions
- Maxheight restrictions
- Maxwidth restrictions
- Hazmat restrictions
- Bridge clearances
- Tunnel restrictions
- Real-time restriction overlay on map

**Data Retrieved:**
- Weight limits (tons)
- Height limits (meters/feet)
- Width limits (meters/feet)
- Special truck restrictions
- Coordinate-based restriction zones

---

### 7. Supabase (Backend Database)

**Services Used:**
- **Supabase PostgreSQL** - Cloud database
- **Supabase Auth** - User authentication
- **Supabase Storage** - File storage for POI data

**Key Features:**
- User account management
- POI (Points of Interest) storage
- Trip history logging
- Saved routes
- Truck profile persistence
- Cross-device sync

**Database Schema:**
```sql
-- Users table
- id (UUID)
- email
- created_at
- truck_profile (JSON)

-- POIs table
- id (UUID)
- user_id (FK)
- name
- category
- latitude
- longitude
- notes
- created_at

-- Routes table
- id (UUID)
- user_id (FK)
- name
- waypoints (JSON)
- distance
- duration
- created_at
```

---

## Core Features

### 1. Truck-Specific Navigation

**Capabilities:**
- Enter truck dimensions:
  - Height (feet)
  - Weight (pounds/tons)
  - Width (feet)
  - Length (feet)
  - Number of axles
  - Number of trailers

- Hazardous materials:
  - Explosive
  - Gas
  - Flammable
  - Combustible
  - Organic
  - Poison
  - Radioactive
  - Corrosive
  - Other dangerous goods

**Routing Logic:**
- Avoid low bridges
- Avoid weight-restricted roads
- Avoid narrow streets
- Avoid hazmat-restricted tunnels
- Calculate safe routes based on profile
- Warning system for upcoming restrictions

**Implementation:**
- Settings stored in UserDefaults
- Dimensions converted to metric for API calls
- Real-time validation against OSM restrictions
- Visual warnings on map

---

### 2. Multi-Stop Routing & Optimization

**Capabilities:**
- Add unlimited stops to route
- Drag-and-drop reordering
- Delete stops with swipe gesture
- Visual numbered markers (1, 2, 3...)
- Estimated time of arrival (ETA) per stop
- Automatic route recalculation on changes

**Optimization:**
- HERE Waypoint Sequence API
- Optimizes for time or distance
- Considers traffic conditions
- Maintains start/end constraints
- Shows time/distance savings

**UI Components:**
- Collapsible stops panel (slides from right)
- Add Stop button (stacked below settings)
- Table view with stop list
- Optimize Route button
- Completed stop checkmarks

**Route Recalculation Triggers:**
- New stop added
- Stop removed
- Stop reordered (drag-and-drop)
- Truck dimensions changed

---

### 3. Live Traffic & Incident Reporting

**Traffic Widget:**
- Real-time traffic status
- Congestion levels:
  - Free Flow (Green) - Jam Factor < 2.0
  - Slow Traffic (Yellow) - Jam Factor 2.0-4.9
  - Congestion (Orange) - Jam Factor 5.0-7.9
  - Heavy Traffic (Red) - Jam Factor ≥ 8.0
- Current speed vs. free-flow speed
- Auto-updates every 3 minutes
- Tap to view detailed incident list

**Incident Display:**
- Color-coded markers on map:
  - Red (Critical): Road closure, major accident
  - Orange (Major): Accident, heavy congestion
  - Yellow (Minor): Light congestion, construction
  - Blue (Info): General notices
- Incident descriptions
- Affected road names
- Estimated delay times

**Incident Types:**
- Accidents
- Road closures
- Construction zones
- Disabled vehicles
- Lane closures
- Weather hazards
- Special events

---

### 4. Weather Integration

**Weather Widget:**
- Current temperature (°F or °C)
- Weather condition icon
- Wind speed (mph or km/h)
- Wind direction (cardinal + degrees)
- "Feels like" temperature
- Precipitation probability
- Auto-updates every 15 minutes

**Weather Radar:**
- Toggle radar overlay on map
- Precipitation intensity visualization
- Real-time radar animation
- Coverage area display

**Settings:**
- Imperial units (°F, mph)
- Metric units (°C, km/h)
- User preference stored

---

### 5. Route Selection & Alternatives

**Route Preview:**
- Main route display
- Up to 3 alternative routes
- Route comparison:
  - Distance
  - Estimated time
  - Tolls
  - Traffic conditions
- Visual route highlighting

**Route Cycling:**
- "Next Route" button during preview
- Cycle through alternatives before navigation
- Route counter: "Route 2 of 3"
- Select preferred route
- Start Navigation button

**Route Display:**
- Primary route (blue line)
- Alternative routes (gray lines)
- Distance and time badges
- Toll indicators
- Traffic overlay

---

### 6. Points of Interest (POI) Management

**POI Categories:**
- Truck stops
- Rest areas
- Weigh stations
- Fuel stations
- Truck parking
- Service centers
- Warehouses
- Delivery locations
- Custom categories

**POI Features:**
- Import POIs from CSV/JSON
- Manual POI creation
- POI detail view with:
  - Name and category
  - Address
  - Phone number
  - Operating hours
  - Amenities
  - Notes
- Navigate to POI
- Add POI as waypoint
- Sync to Supabase

**POI Import Service:**
- CSV format support
- Batch import
- Validation and error handling
- Progress tracking

---

### 7. Search History & Favorites

**Recent Searches:**
- Stores last 20 searches
- Duplicate detection (by name or coordinate within 10m)
- Timestamp for each search
- Quick access from search bar
- Clear history option

**Favorites:**
- Star/unstar locations
- Persistent favorites list
- Favorite marker on map
- Quick navigation to favorites
- Sync across devices (via Supabase)

**Storage:**
- UserDefaults for local persistence
- JSON encoding/decoding
- SavedLocation model:
  - ID (UUID)
  - Name
  - Address
  - Coordinate
  - Timestamp
  - isFavorite flag

---

### 8. Speed Limit Display

**Features:**
- Real-time speed limit detection
- Display during navigation
- Uses Mapbox road attributes
- Visual speed limit sign
- Updates on road changes
- Overspeed warning (future feature)

**Display:**
- White circle with black border
- Speed in mph or km/h
- Positioned near navigation puck
- Fades in/out on road changes

---

### 9. Hazard Warning System

**Warning Types:**
- Low bridge ahead
- Weight restriction
- Width restriction
- Sharp curve
- Steep grade
- Hazmat restriction
- School zone
- Construction zone

**Warning Display:**
- Visual alert on map
- Distance to hazard
- Warning icon
- Text description
- Audio alert (optional)

**Settings:**
- Enable/disable warnings
- Warning distance threshold
- Audio alert volume
- Warning types to show

---

### 10. Settings & Customization

**Truck Profile Settings:**
- Height (ft/in)
- Weight (lbs/kg)
- Width (ft/in)
- Length (ft/in)
- Axle count
- Trailer count
- Hazmat cargo

**Map Settings:**
- Map style (satellite, streets, dark)
- 3D buildings toggle
- Traffic layer toggle
- Weather radar toggle
- Restriction overlay toggle

**Navigation Settings:**
- Voice guidance on/off
- Voice volume
- Avoid tolls
- Avoid highways
- Avoid ferries
- Route preference (fastest/shortest)

**Units:**
- Distance (miles/km)
- Temperature (°F/°C)
- Wind speed (mph/km/h)

**Account:**
- Sign in/out
- Subscription status
- Restore purchases
- Delete account
- Privacy settings

---

## Technical Architecture

### Navigation Flow

```
User Input → Search/POI
    ↓
Geocoding (MapKit)
    ↓
HERE Routing API (truck profile)
    ↓
Mapbox Navigation SDK (turn-by-turn)
    ↓
Real-time Updates:
    - Location (Core Location)
    - Traffic (HERE/TomTom)
    - Weather (WeatherKit)
    - Restrictions (OSM)
```

### Service Fallback Strategy

```
Primary: HERE Technologies
    ↓ (if fails)
Fallback: TomTom
    ↓ (if fails)
Error: Show user notification
```

### Data Persistence

```
Local:
- UserDefaults (settings, favorites, search history)
- CoreData (offline maps, cached routes)

Cloud:
- Supabase (user account, POIs, saved routes)
- RevenueCat (subscription status)
```

---

## API Rate Limits & Quotas

### HERE Technologies
- Routing: 250,000 requests/month (free tier)
- Traffic: 100,000 requests/month (free tier)
- Waypoint Sequence: 50,000 requests/month (free tier)

### TomTom
- Routing: 2,500 requests/day (free tier)
- Traffic: 2,500 requests/day (free tier)

### Mapbox
- Map Loads: 200,000/month (free tier)
- Directions: 100,000 requests/month (free tier)

### Apple WeatherKit
- 500,000 API calls/month (free tier)

### OpenStreetMap Overpass
- No official limit, but rate-limited by server
- Recommended: Cache results, batch requests

---

## Future Enhancements

### Planned Features
- Offline map downloads
- Fleet management integration
- Delivery tracking
- Hours of Service (HOS) logging
- Fuel cost calculator
- Truck parking availability
- Real-time weigh station status
- Load board integration
- ELD (Electronic Logging Device) integration

### API Considerations
- Explore HERE Fleet Telematics for advanced features
- Consider HERE Positioning API for enhanced GPS
- Evaluate HERE EV Routing for electric trucks
- Potential integration with DAT Load Board API
- Explore KeepTruckin API for ELD integration

---

## Support & Documentation

**GitHub Repository:** https://github.com/derrickgray494-rgb/TruckProNav

**Support Channels:**
- GitHub Issues: https://github.com/derrickgray494-rgb/TruckProNav/issues
- Support Documentation: SUPPORT.md

**Legal:**
- Privacy Policy: PRIVACY_POLICY.md
- Terms of Service: TERMS_OF_SERVICE.md
- End-User License Agreement: EULA.md

**Anonymous Developer:**
The developer(s) of TruckNavPro choose to remain anonymous. All support and communications are handled through GitHub.

---

## Bundle ID & Configuration

**App Bundle ID:** `com.trucknav.pro`

**Minimum iOS Version:** 16.0

**Required Capabilities:**
- Location Services (Always/When In Use)
- Background Location Updates
- Network Access
- Push Notifications (for alerts)
- In-App Purchases

**Required API Keys:**
- HERE API Key (routing, traffic)
- TomTom API Key (fallback services)
- Mapbox Access Token (maps, navigation)
- RevenueCat API Key (subscriptions)
- Supabase URL + Anon Key (backend)

---

## Conclusion

TruckNavPro integrates best-in-class APIs and services to deliver professional truck navigation with real-time traffic, weather, and route optimization. Built with a robust fallback strategy and comprehensive feature set, it provides truck drivers with the tools they need for safe and efficient navigation.

**USE AT YOUR OWN RISK:** TruckNavPro is a navigation aid. Drivers are solely responsible for safe operation of their vehicles and compliance with all traffic laws and regulations.

---

**Last Updated:** January 12, 2025
**Version:** 1.0
**Developer:** Anonymous (GitHub: derrickgray494-rgb)
