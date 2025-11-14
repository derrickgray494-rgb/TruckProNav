//
//  MapViewController+CustomSearch.swift
//  TruckNavPro
//

import UIKit
import CoreLocation
import MapboxSearchUI
import MapboxMaps

// MARK: - Associated Object Keys

private struct AssociatedKeys {
    static var customSearchBar: UInt8 = 0
    static var searchBarBottomConstraint: UInt8 = 0
    static var searchResultsTable: UInt8 = 0
}

extension MapViewController {

    // MARK: - Memory Management

    // Note: deinit is called on the main MapViewController class, not the extension
    // We handle cleanup there, but adding this comment for clarity

    // To properly clean up keyboard observers, add this to MapViewController.swift deinit:
    // NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    // NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)

    // MARK: - Custom Search Bar Setup

    func setupCustomSearchBar() {
        let customSearchBar = CustomSearchBar()
        customSearchBar.delegate = self
        customSearchBar.translatesAutoresizingMaskIntoConstraints = false

        // Create search results table
        let resultsTable = SearchResultsTableView()
        resultsTable.translatesAutoresizingMaskIntoConstraints = false
        resultsTable.isHidden = true
        resultsTable.alpha = 0  // Start invisible for animation

        view.addSubview(resultsTable)
        view.addSubview(customSearchBar)

        // Store constraints for keyboard adjustment
        let bottomConstraint = customSearchBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)

        // Height constraint for results table - make it explicit and sizeable
        let resultsHeightConstraint = resultsTable.heightAnchor.constraint(equalToConstant: 280)

        NSLayoutConstraint.activate([
            // Results table above search bar with FIXED HEIGHT
            resultsTable.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultsTable.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultsTable.bottomAnchor.constraint(equalTo: customSearchBar.topAnchor, constant: -8),
            resultsHeightConstraint,  // Fixed height for visibility

            // Search bar at bottom
            customSearchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            customSearchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomConstraint
        ])

        // Store references for keyboard handling
        objc_setAssociatedObject(self, &AssociatedKeys.customSearchBar, customSearchBar, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.searchBarBottomConstraint, bottomConstraint, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssociatedKeys.searchResultsTable, resultsTable, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Handle result selection
        resultsTable.onResultSelected = { [weak self] result in
            self?.handleSearchResultSelection(result)
        }

        // MapboxPanelController is now completely disabled - using custom search only
        // panelController.view.isHidden = true

        // Bring to front
        view.bringSubviewToFront(resultsTable)
        view.bringSubviewToFront(customSearchBar)

        // Setup keyboard notifications
        setupKeyboardNotifications()

        print("✅ Custom liquid glass search bar initialized")
    }

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let bottomConstraint = objc_getAssociatedObject(self, &AssociatedKeys.searchBarBottomConstraint) as? NSLayoutConstraint else {
            return
        }

        let keyboardHeight = keyboardFrame.height
        bottomConstraint.constant = -keyboardHeight - 8

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }

        print("⌨️ Keyboard shown - search bar raised")
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let bottomConstraint = objc_getAssociatedObject(self, &AssociatedKeys.searchBarBottomConstraint) as? NSLayoutConstraint else {
            return
        }

        bottomConstraint.constant = -16

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }

        print("⌨️ Keyboard hidden - search bar lowered")
    }

    // MARK: - Z-Order Management

    func bringSearchUIToFront() {
        // Bring search results table and search bar to the very front
        if let resultsTable = objc_getAssociatedObject(self, &AssociatedKeys.searchResultsTable) as? SearchResultsTableView {
            view.bringSubviewToFront(resultsTable)
        }
        if let customSearchBar = objc_getAssociatedObject(self, &AssociatedKeys.customSearchBar) as? CustomSearchBar {
            view.bringSubviewToFront(customSearchBar)
        }
        print("🔝 Search UI brought to front")
    }

    // MARK: - Search Helpers

    func performTextSearch(query: String) {
        guard !query.isEmpty else { return }
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location for search")
            showSearchAlert(title: "Location Required", message: "Please enable location services to search.")
            return
        }

        print("🔍 Searching for: \(query) near \(userLocation.latitude), \(userLocation.longitude)")

        // Try HERE first (primary)
        if let hereService = hereSearchService {
            print("🗺️ Using HERE Search (primary)...")
            hereService.searchText(query, near: userLocation, limit: 50) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let hereResults):
                        print("✅ HERE Search returned \(hereResults.count) results")
                        // Convert HERE results to TomTom format for compatibility
                        let results = hereResults.map { here in
                            TomTomSearchService.TruckSearchResult(
                                id: here.id,
                                name: here.name,
                                category: here.category,
                                distance: here.distance,
                                coordinate: here.coordinate,
                                address: here.address,
                                phone: here.phone,
                                categories: here.categories
                            )
                        }

                        if results.isEmpty {
                            self?.showSearchAlert(title: "No Results", message: "No results found for '\(query)'. Try a different search term.")
                        } else {
                            self?.showSearchResults(results, userLocation: userLocation, query: query)
                        }
                    case .failure(let error):
                        print("❌ HERE search failed: \(error.localizedDescription)")
                        // Try TomTom as fallback
                        self?.tryTomTomSearchFallback(query: query, userLocation: userLocation, hereError: error)
                    }
                }
            }
        } else {
            // HERE not available, try TomTom directly
            print("⚠️ HERE not available, trying TomTom Search...")
            tryTomTomSearchFallback(query: query, userLocation: userLocation, hereError: nil)
        }
    }

    private func tryTomTomSearchFallback(query: String, userLocation: CLLocationCoordinate2D, hereError: Error?) {
        guard let tomTomService = tomTomSearchService else {
            // Neither service available
            let message = hereError != nil
                ? "HERE Search failed and TomTom Search is not configured.\n\nHERE error: \(hereError!.localizedDescription)"
                : "Search services not configured. Please add HEREAPIKey or TomTomAPIKey to Info.plist.\n\nGet keys at:\nhttps://developer.here.com/\nhttps://developer.tomtom.com/"
            showSearchAlert(title: "Search Unavailable", message: message)
            return
        }

        print("🗺️ Falling back to TomTom Search...")
        tomTomService.searchText(query, near: userLocation, limit: 50) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let results):
                    print("✅ TomTom Search returned \(results.count) results")

                    if results.isEmpty {
                        self?.showSearchAlert(title: "No Results", message: "No results found for '\(query)'. Try a different search term.")
                    } else {
                        self?.showSearchResults(results, userLocation: userLocation, query: query)
                    }

                case .failure(let error):
                    print("❌ TomTom Search also failed: \(error.localizedDescription)")

                    // Both services failed - show comprehensive error
                    let errorMessage: String
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            errorMessage = "No internet connection. Please check your network settings."
                        case .timedOut:
                            errorMessage = "Search timed out. Please try again."
                        default:
                            errorMessage = "Network error: \(urlError.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Both HERE and TomTom Search failed.\n\nHERE: \(hereError?.localizedDescription ?? "Not available")\nTomTom: \(error.localizedDescription)\n\nCheck API keys at:\nhttps://developer.here.com/\nhttps://developer.tomtom.com/"
                    }

                    self?.showSearchAlert(title: "Search Error", message: errorMessage)
                }
            }
        }
    }

    func performCategorySearch(category: TruckQuickCategory) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("⚠️ No user location for category search")
            showSearchAlert(title: "Location Required", message: "Please enable location services to search.")
            return
        }

        print("📂 Searching category: \(category.rawValue) near \(userLocation.latitude), \(userLocation.longitude)")

        // Try HERE first (primary)
        if let hereService = hereSearchService {
            print("🗺️ Using HERE Category Search (primary)...")
            let searchQuery = getCategorySearchQuery(for: category)

            hereService.searchText(searchQuery, near: userLocation, limit: 50) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let hereResults):
                        print("✅ HERE Category Search returned \(hereResults.count) results for \(category.rawValue)")
                        // Convert HERE results to TomTom format for compatibility
                        let results = hereResults.map { here in
                            TomTomSearchService.TruckSearchResult(
                                id: here.id,
                                name: here.name,
                                category: here.category,
                                distance: here.distance,
                                coordinate: here.coordinate,
                                address: here.address,
                                phone: here.phone,
                                categories: here.categories
                            )
                        }

                        if results.isEmpty {
                            self?.showSearchAlert(title: "No Results", message: "No \(category.rawValue.lowercased()) found nearby. Try expanding your search area.")
                        } else {
                            self?.showSearchResults(results, userLocation: userLocation, category: category.rawValue)
                        }
                    case .failure(let error):
                        print("❌ HERE category search failed: \(error.localizedDescription)")
                        // Try TomTom as fallback
                        self?.tryTomTomCategorySearchFallback(category: category, userLocation: userLocation, hereError: error)
                    }
                }
            }
        } else {
            // HERE not available, try TomTom directly
            print("⚠️ HERE not available, trying TomTom Category Search...")
            tryTomTomCategorySearchFallback(category: category, userLocation: userLocation, hereError: nil)
        }
    }

    private func tryTomTomCategorySearchFallback(category: TruckQuickCategory, userLocation: CLLocationCoordinate2D, hereError: Error?) {
        guard let tomTomService = tomTomSearchService else {
            // Neither service available
            let message = hereError != nil
                ? "HERE Search failed and TomTom Search is not configured.\n\nHERE error: \(hereError!.localizedDescription)"
                : "Search services not configured. Please add HEREAPIKey or TomTomAPIKey to Info.plist.\n\nGet keys at:\nhttps://developer.here.com/\nhttps://developer.tomtom.com/"
            showSearchAlert(title: "Search Unavailable", message: message)
            return
        }

        print("🗺️ Falling back to TomTom Category Search for \(category.rawValue)...")

        let tomTomCategory = category.tomTomCategory
        tomTomService.searchCategory(
            tomTomCategory,
            near: userLocation,
            radius: 80000, // 80km radius for better coverage
            limit: 50
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let results):
                    print("✅ TomTom Category Search returned \(results.count) results for \(category.rawValue)")

                    if results.isEmpty {
                        self?.showSearchAlert(title: "No Results", message: "No \(category.rawValue.lowercased()) found nearby. Try expanding your search area.")
                    } else {
                        self?.showSearchResults(results, userLocation: userLocation, category: category.rawValue)
                    }

                case .failure(let error):
                    print("❌ TomTom Category Search also failed: \(error.localizedDescription)")

                    // Both services failed - show comprehensive error
                    let errorMessage: String
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            errorMessage = "No internet connection. Please check your network settings."
                        case .timedOut:
                            errorMessage = "Search timed out. Please try again."
                        default:
                            errorMessage = "Network error: \(urlError.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Both HERE and TomTom Search failed.\n\nHERE: \(hereError?.localizedDescription ?? "Not available")\nTomTom: \(error.localizedDescription)\n\nCheck API keys at:\nhttps://developer.here.com/\nhttps://developer.tomtom.com/"
                    }

                    self?.showSearchAlert(title: "Search Error", message: errorMessage)
                }
            }
        }
    }

    private func getCategorySearchQuery(for category: TruckQuickCategory) -> String {
        switch category {
        case .truckStops: return "truck stop"
        case .fuel: return "gas station"
        case .restAreas: return "rest area"
        case .weighStations: return "weigh station"
        case .parking: return "truck parking"
        case .restaurants: return "restaurant"
        }
    }

    private func showSearchAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Search Results Display

    private func showSearchResults(_ results: [TomTomSearchService.TruckSearchResult], userLocation: CLLocationCoordinate2D, query: String? = nil, category: String? = nil) {
        guard let resultsTable = objc_getAssociatedObject(self, &AssociatedKeys.searchResultsTable) as? SearchResultsTableView else {
            print("❌ Results table not found!")
            return
        }

        // Update results data
        resultsTable.updateResults(results, userLocation: userLocation, query: query, category: category)

        // Hide overlapping UI elements (recenter/settings buttons) when results are shown
        UIView.animate(withDuration: 0.2) {
            self.recenterButton.alpha = 0.3
            self.settingsButton.alpha = 0.3
        }

        // Ensure search UI is visible on top of everything
        bringSearchUIToFront()

        // Show with animation
        resultsTable.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            resultsTable.alpha = 1.0
        }

        print("📋 Showing \(results.count) results in list")
        print("📏 Table frame after update: \(resultsTable.frame)")
        print("🎯 Table superview: \(resultsTable.superview != nil)")
    }

    private func handleSearchResultSelection(_ result: TomTomSearchService.TruckSearchResult) {
        // Hide results table with animation
        if let resultsTable = objc_getAssociatedObject(self, &AssociatedKeys.searchResultsTable) as? SearchResultsTableView {
            UIView.animate(withDuration: 0.2, animations: {
                resultsTable.alpha = 0
            }, completion: { _ in
                resultsTable.isHidden = true
                resultsTable.clearResults()
            })
        }

        // Restore UI elements visibility
        UIView.animate(withDuration: 0.2) {
            self.recenterButton.alpha = 1.0
            self.settingsButton.alpha = 1.0
        }

        // Hide keyboard
        if let searchBar = objc_getAssociatedObject(self, &AssociatedKeys.customSearchBar) as? CustomSearchBar {
            searchBar.textField.resignFirstResponder()
            searchBar.textField.text = result.name  // Show selected location
        }

        print("📍 Selected: \(result.name) at \(result.coordinate)")

        // Calculate route to selected location
        calculateRoute(to: result.coordinate)
    }

    private func displayTomTomSearchResults(_ results: [TomTomSearchService.TruckSearchResult], query: String? = nil, category: String? = nil) {
        // Clear previous annotations
        clearSearchAnnotations()

        if results.isEmpty {
            print("⚠️ No results found")
            return
        }

        // Create annotations for each result
        var annotations: [PointAnnotation] = []

        for result in results {
            var annotation = PointAnnotation(coordinate: result.coordinate)
            annotation.textField = result.name
            annotation.textColor = StyleColor(.label)
            annotation.textHaloColor = StyleColor(.systemBackground)
            annotation.textHaloWidth = 2
            annotation.textOffset = [0, -1.5]
            annotation.textSize = 12

            // Use category-specific icon or default pin
            if let category = category {
                annotation.iconImage = iconForCategory(category)
            } else {
                annotation.iconImage = "mappin.circle.fill"
            }
            annotation.iconSize = 1.5
            annotation.iconColor = StyleColor(.systemBlue)

            annotations.append(annotation)
        }

        // Add annotations to map
        pointAnnotationManager.annotations = annotations

        // Fit camera to show all results
        let coordinates = results.map { $0.coordinate }
        fitCameraToAnnotations(coordinates: coordinates)

        if let category = category {
            print("✅ Displayed \(results.count) \(category) results")
        } else if let query = query {
            print("✅ Displayed \(results.count) results for '\(query)'")
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "truck stops": return "fuelpump.circle.fill"
        case "fuel": return "fuelpump.fill"
        case "rest areas": return "bed.double.fill"
        case "weigh stations": return "scalemass.fill"
        case "parking": return "parkingsign.circle.fill"
        case "restaurants": return "fork.knife.circle.fill"
        default: return "mappin.circle.fill"
        }
    }
}

// MARK: - CustomSearchBarDelegate

extension MapViewController: CustomSearchBarDelegate {

    func searchBarDidBeginEditing(_ searchBar: CustomSearchBar) {
        // Hide results table when user starts typing again
        if let resultsTable = objc_getAssociatedObject(self, &AssociatedKeys.searchResultsTable) as? SearchResultsTableView {
            UIView.animate(withDuration: 0.2, animations: {
                resultsTable.alpha = 0
            }, completion: { _ in
                resultsTable.isHidden = true
            })
        }

        // Restore UI elements
        UIView.animate(withDuration: 0.2) {
            self.recenterButton.alpha = 1.0
            self.settingsButton.alpha = 1.0
        }

        print("🔍 Search began")
    }

    func searchBar(_ searchBar: CustomSearchBar, textDidChange searchText: String) {
        // Hide results when text changes
        if let resultsTable = objc_getAssociatedObject(self, &AssociatedKeys.searchResultsTable) as? SearchResultsTableView,
           !resultsTable.isHidden {
            UIView.animate(withDuration: 0.2, animations: {
                resultsTable.alpha = 0
            }, completion: { _ in
                resultsTable.isHidden = true
            })

            // Restore UI elements
            UIView.animate(withDuration: 0.2) {
                self.recenterButton.alpha = 1.0
                self.settingsButton.alpha = 1.0
            }
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: CustomSearchBar) {
        guard let query = searchBar.textField.text, !query.isEmpty else { return }
        performTextSearch(query: query)
    }

    func searchBar(_ searchBar: CustomSearchBar, didSelectCategory category: TruckQuickCategory) {
        performCategorySearch(category: category)
    }
}
