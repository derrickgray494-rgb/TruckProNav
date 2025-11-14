# TruckNavPro Performance Optimization - Quick Reference Guide

## Critical Issues (Fix First - 65 min total)

### Issue #1: Memory Leak - Keyboard Notifications
- **File:** `MapViewController+CustomSearch.swift` Lines 79-92
- **Problem:** Notifications registered but never cleaned up
- **Fix:** Add `deinit` with `NotificationCenter.default.removeObserver(self)`
- **Time:** 5 min | **Impact:** Prevents memory leaks

### Issue #2: Network Tasks Never Cancelled  
- **File:** `TomTomSearchService.swift` Line 97, `HERESearchService.swift` Line 84
- **Problem:** Old requests complete out of order showing stale results
- **Fix:** Store `URLSessionDataTask`, call `.cancel()` on new search
- **Time:** 30 min | **Impact:** Eliminates UI jank from stale data

### Issue #3: Full Table Reloads on Minor Changes
- **File:** `SettingsViewController.swift` Lines 415, 501, 615, 662, 691
- **Problem:** Entire table refreshes when only 1-2 cells changed
- **Fix:** Use `reloadRows(at:with:)` instead of `reloadData()`
- **Time:** 20 min | **Impact:** Smooth Settings UI transitions

### Issue #4: Search Results Table Layout
- **File:** `SearchResultsTableView.swift` Lines 101-123
- **Problem:** layoutIfNeeded() forces expensive layout pass
- **Fix:** Remove layoutIfNeeded(), let constraints animate
- **Time:** 10 min | **Impact:** Faster search result display

---

## High Priority Issues (65 min total)

### Issue #5: Expensive Blur on Scroll
- **File:** `SearchResultsTableView.swift` Lines 31-36
- **Problem:** Blur effect causes frame drops during scrolling
- **Fix:** Replace blur with solid semi-transparent color
- **Time:** 10 min | **Impact:** 60 FPS maintained while scrolling

### Issue #6: No Image Caching
- **File:** `WeatherWidgetView.swift`, `TrafficWidgetView.swift`
- **Problem:** SF Symbols recreated on every update (every 3 minutes)
- **Fix:** Add `NSCache<NSString, UIImage>` for symbol caching
- **Time:** 20 min | **Impact:** Reduce CPU usage during updates

### Issue #7: Traffic Timer Continues in Background
- **File:** `NavigationViewController.swift` Lines 844-854
- **Problem:** Timer continues making API calls when app backgrounded
- **Fix:** Invalidate in `viewWillDisappear()`, restart in `viewWillAppear()`
- **Time:** 15 min | **Impact:** Better battery life

### Issue #8: Waypoint Table Updates
- **File:** `NavigationViewController+Waypoints.swift` Lines 280, 340, 358, 374, 390, 609
- **Problem:** Full reload on every add/remove/reorder operation
- **Fix:** Use `insertRows()`, `deleteRows()`, `moveRow()`
- **Time:** 20 min | **Impact:** Smooth waypoint management

---

## Medium Priority Issues (75 min total)

### Issue #9: JSON Decoding on Main Thread
- **File:** `TomTomSearchService.swift` Lines 119-147
- **Problem:** Large JSON responses block UI during parsing
- **Fix:** Decode on `DispatchQueue.global()`, dispatch to main for updates
- **Time:** 15 min | **Impact:** No UI freeze on large result sets

### Issue #10: Associated Objects Instead of Properties
- **File:** `MapViewController+CustomSearch.swift` Lines 13-17, 57-59
- **Problem:** Slower than direct properties, prone to bugs
- **Fix:** Add `customSearchBar`, `searchBarBottomConstraint` as properties
- **Time:** 5 min | **Impact:** Cleaner code, faster access

### Issue #11: PaywallViewController Cache Invalidation
- **File:** `PaywallViewController.swift` Line 168
- **Problem:** Network call made every time paywall shown
- **Fix:** Remove `invalidateCustomerInfoCache()` from viewDidLoad
- **Time:** 5 min | **Impact:** Faster paywall display

### Issue #12: Weather Update Too Frequent
- **File:** `NavigationViewController.swift` Lines 2139-2149
- **Problem:** Weather fetched on every location update (even small moves)
- **Fix:** Check distance delta (>10km) before API call
- **Time:** 15 min | **Impact:** Fewer API calls, save quota

### Issue #13: View Hierarchy Z-Order
- **File:** `NavigationViewController.swift` Lines 308-320
- **Problem:** 10 sequential `bringSubviewToFront()` calls trigger 10 layouts
- **Fix:** Arrange views in correct order during initial setup
- **Time:** 5 min | **Impact:** Faster startup

### Issue #14: Hazard Warning View Not Reused
- **File:** `NavigationViewController.swift` Lines 2241-2269
- **Problem:** New view created for each hazard instead of updating existing
- **Fix:** Reuse existing view or update it instead of creating new
- **Time:** 10 min | **Impact:** Reduced allocations

### Issue #15: Distance Pre-calculations
- **File:** `SearchResultsTableView.swift` Lines 149-160
- **Problem:** CLLocation distance calculated for each visible cell
- **Fix:** Pre-calculate all distances when data loads
- **Time:** 10 min | **Impact:** Smoother table scrolling

---

## Lower Priority Issues (70 min total)

### Issue #16: Constraint Conflicts on Rotation
- **File:** `MapViewController+CustomSearch.swift` Lines 38-54
- **Problem:** Fixed 280px height conflicts on landscape rotation
- **Fix:** Use `lessThanOrEqualToConstant` instead of `equalToConstant`
- **Time:** 10 min | **Impact:** No console warnings

### Issue #17: URLSession Cache Policy
- **File:** All service files (TomTomSearchService, HERESearchService, etc.)
- **Problem:** Default cache policy, no aggressive caching
- **Fix:** Create custom `URLSessionConfiguration` with caching
- **Time:** 30 min | **Impact:** Reduced network traffic

### Issue #18: Search Results Pagination
- **File:** `SearchResultsTableView.swift`
- **Problem:** All 50 results allocated at once
- **Fix:** Load 10 results, add 10 more when scrolling near bottom
- **Time:** 30 min | **Impact:** Lower memory, faster initial display

---

## Implementation Roadmap

### Week 1 (Monday-Tuesday) - Critical Path
- [ ] Add deinit to MapViewController - 5 min
- [ ] Implement network task cancellation - 30 min
- [ ] Replace reloadData with reloadRows - 20 min
- [ ] Fix search results table layout - 10 min

**Total: 65 minutes | Impact: 70% improvement in perceived performance**

### Week 1 (Wednesday-Thursday) - High Impact
- [ ] Remove blur effect or replace - 10 min
- [ ] Add SF Symbol caching - 20 min
- [ ] Fix traffic timer background issue - 15 min
- [ ] Update waypoint operations - 20 min

**Total: 65 minutes | Impact: Additional 20% improvement**

### Week 2 (Friday+) - Polish & Long-term
- [ ] Background JSON decoding - 15 min
- [ ] Replace associated objects - 5 min
- [ ] Remove PaywallViewController cache invalidation - 5 min
- [ ] Add weather distance checking - 15 min
- [ ] Fix view hierarchy order - 5 min
- [ ] Reuse hazard warning view - 10 min
- [ ] Pre-calculate distances - 10 min
- [ ] Constraint fixes - 10 min
- [ ] URLSession caching - 30 min (optional)
- [ ] Search pagination - 30 min (optional)

**Total: 135 minutes | Impact: Fine-tuning for remaining 10% improvement**

---

## Performance Metrics to Monitor

### Before Optimization
- [ ] Memory usage (MB)
- [ ] FPS during scroll (target: 60)
- [ ] Time to display search results (ms)
- [ ] Settings table reload time (ms)
- [ ] Battery drain (mA/hour)
- [ ] Network requests per session

### After Optimization
- [ ] Target: 50% reduction in memory
- [ ] Target: 60 FPS consistently maintained
- [ ] Target: <500ms search result display
- [ ] Target: <100ms settings reload
- [ ] Target: 30% less battery drain
- [ ] Target: 40% fewer network requests

---

## Testing Checklist

### Functional Testing
- [ ] Search results display correctly
- [ ] Settings changes persist
- [ ] Waypoint operations smooth
- [ ] Traffic updates work on background
- [ ] No duplicate network requests
- [ ] No console memory warnings

### Performance Testing
- [ ] Run with Instruments > Core Animation
- [ ] Check FPS during: scroll, keyboard animation, search
- [ ] Monitor memory with Xcode debugger
- [ ] Verify network tab shows cancelled requests
- [ ] Check battery drain with longer test drives

### Device Testing
- [ ] iPhone 13 Pro (baseline)
- [ ] iPhone 11 (identify remaining issues)
- [ ] iPhone SE 3rd Gen (oldest supported)
- [ ] iPad Air (landscape handling)

---

## Files Most Critical for Performance

```
Priority 1 (Fix First):
├── MapViewController+CustomSearch.swift (4 issues)
├── SettingsViewController.swift (1 issue)
├── SearchResultsTableView.swift (2 issues)
└── NavigationViewController.swift (3 issues)

Priority 2 (High Impact):
├── TomTomSearchService.swift (1 issue)
├── WeatherWidgetView.swift (1 issue)
├── TrafficWidgetView.swift (1 issue)
└── NavigationViewController+Waypoints.swift (1 issue)

Priority 3 (Polish):
├── PaywallViewController.swift (1 issue)
├── All service files (1 issue: caching)
└── HERESearchService.swift (1 issue)
```

---

## Common Performance Mistakes to Avoid

1. **Never** call `layoutIfNeeded()` inside `UIView.animate()`
2. **Never** store `URLSessionDataTask` without canceling old ones
3. **Never** use `reloadData()` when only a few cells changed
4. **Never** run expensive operations (JSON, calculations) on main thread
5. **Never** let timers continue when app backgrounded
6. **Never** add notification observers without removing in deinit
7. **Never** apply blur effects on frequently updated views
8. **Never** recreate image objects that could be cached

---

## Questions to Ask When Optimizing

- Is this operation necessary?
- Can this be cached?
- Should this run on background thread?
- Is this view recreated unnecessarily?
- Are there overlapping/redundant operations?
- Does this work correctly when backgrounded?
- Is memory properly cleaned up?

