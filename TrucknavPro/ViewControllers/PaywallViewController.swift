//
//  PaywallViewController.swift
//  TruckNavPro
//

import UIKit
import RevenueCat

class PaywallViewController: UIViewController {

    var requiredFeature: Feature?
    var onComplete: (() -> Void)?
    private var offerings: Offerings?

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let packageStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let restoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Restore Purchases", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let termsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Terms & Privacy", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        button.setTitleColor(.tertiaryLabel, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadOfferings()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(closeButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(packageStackView)
        contentView.addSubview(restoreButton)
        contentView.addSubview(termsButton)

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        termsButton.addTarget(self, action: #selector(termsTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            closeButton.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            packageStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            packageStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            packageStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            restoreButton.topAnchor.constraint(equalTo: packageStackView.bottomAnchor, constant: 32),
            restoreButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            termsButton.topAnchor.constraint(equalTo: restoreButton.bottomAnchor, constant: 16),
            termsButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            termsButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])

        // Set content based on required feature
        if let feature = requiredFeature {
            titleLabel.text = "Unlock \(feature.displayName)"
            subtitleLabel.text = "Upgrade to \(feature.requiredTier.displayName) to access this feature"
        } else {
            titleLabel.text = "Upgrade to Pro"
            subtitleLabel.text = "Get unlimited access to all premium features"
        }
    }

    // MARK: - Load Offerings

    private func loadOfferings() {
        print("🔄 Starting to load offerings from RevenueCat...")

        // Invalidate cache to fetch fresh offerings
        Purchases.shared.invalidateCustomerInfoCache()
        print("🗑️ Cache invalidated, fetching fresh offerings...")

        Task {
            do {
                offerings = try await RevenueCatService.shared.getOfferings()
                print("✅ Offerings loaded successfully")
                print("📦 Total offerings: \(offerings?.all.count ?? 0)")
                print("📦 Available offerings: \(offerings?.all.keys.joined(separator: ", ") ?? "none")")
                print("📦 Current offering: \(offerings?.current?.identifier ?? "not set")")

                await MainActor.run {
                    displayPackages()
                }
            } catch {
                print("❌ Error loading offerings: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    showError("Unable to load subscription options. Please try again later.\n\nError: \(error.localizedDescription)")
                }
            }
        }
    }

    private func displayPackages() {
        print("📱 displayPackages() called")

        guard let offerings = offerings else {
            print("❌ No offerings available")
            showError("No subscription options available. Please check your RevenueCat configuration.")
            return
        }

        print("✅ Offerings object exists")

        guard let current = offerings.current else {
            print("❌ No current offering set in RevenueCat")
            print("📦 Available offerings: \(offerings.all.keys.joined(separator: ", "))")

            // Try to use the first available offering if current is not set
            if let firstOffering = offerings.all.values.first {
                print("ℹ️ Using first available offering: \(firstOffering.identifier)")
                displayPackagesFromOffering(firstOffering)
            } else {
                print("❌ No offerings at all in RevenueCat!")
                showError("No current offering is set in RevenueCat. Please set a 'current' offering in your RevenueCat dashboard.")
            }
            return
        }

        print("✅ Current offering found: \(current.identifier)")
        displayPackagesFromOffering(current)
    }

    private func displayPackagesFromOffering(_ offering: Offering) {
        print("📦 displayPackagesFromOffering() called for: \(offering.identifier)")

        // Clear existing package views
        packageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        print("🗑️ Cleared existing package views")

        print("📦 Available packages count: \(offering.availablePackages.count)")

        guard !offering.availablePackages.isEmpty else {
            print("❌ No packages available in offering '\(offering.identifier)'")
            showError("No subscription packages available. Please configure products in RevenueCat.")
            return
        }

        // Add package cards
        for (index, package) in offering.availablePackages.enumerated() {
            print("➕ Adding package \(index + 1): \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
            let packageView = createPackageView(for: package)
            packageStackView.addArrangedSubview(packageView)
        }

        print("✅ Displayed \(offering.availablePackages.count) packages from offering '\(offering.identifier)'")
    }

    private func createPackageView(for package: Package) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous

        let nameLabel = UILabel()
        nameLabel.text = package.storeProduct.localizedTitle
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let priceLabel = UILabel()
        priceLabel.text = package.storeProduct.localizedPriceString
        priceLabel.font = .systemFont(ofSize: 28, weight: .bold)
        priceLabel.textColor = .systemBlue
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = package.storeProduct.localizedDescription
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let subscribeButton = UIButton(type: .system)
        subscribeButton.setTitle("Subscribe", for: .normal)
        subscribeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        subscribeButton.backgroundColor = .systemBlue
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.layer.cornerRadius = 12
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        subscribeButton.tag = package.hashValue
        subscribeButton.addTarget(self, action: #selector(subscribeTapped(_:)), for: .touchUpInside)

        // Store package reference
        objc_setAssociatedObject(subscribeButton, &packageKey, package, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        container.addSubview(nameLabel)
        container.addSubview(priceLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(subscribeButton)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            priceLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            descriptionLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            subscribeButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            subscribeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subscribeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            subscribeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            subscribeButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        return container
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true) {
            self.onComplete?()
        }
    }

    @objc private func subscribeTapped(_ sender: UIButton) {
        guard let package = objc_getAssociatedObject(sender, &packageKey) as? Package else {
            return
        }

        sender.isEnabled = false
        sender.setTitle("Processing...", for: .normal)

        Task {
            do {
                let result = try await RevenueCatService.shared.purchase(package: package)
                if !result.userCancelled {
                    await MainActor.run {
                        showSuccess("Subscription activated!")
                        dismiss(animated: true) {
                            self.onComplete?()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    showError("Purchase failed: \(error.localizedDescription)")
                    sender.isEnabled = true
                    sender.setTitle("Subscribe", for: .normal)
                }
            }
        }
    }

    @objc private func restoreTapped() {
        restoreButton.isEnabled = false
        restoreButton.setTitle("Restoring...", for: .normal)

        Task {
            do {
                _ = try await RevenueCatService.shared.restorePurchases()
                await MainActor.run {
                    showSuccess("Purchases restored!")
                    dismiss(animated: true) {
                        self.onComplete?()
                    }
                }
            } catch {
                await MainActor.run {
                    showError("Restore failed: \(error.localizedDescription)")
                    restoreButton.isEnabled = true
                    restoreButton.setTitle("Restore Purchases", for: .normal)
                }
            }
        }
    }

    @objc private func termsTapped() {
        // Show action sheet with options for Terms, Privacy, and EULA
        let alert = UIAlertController(title: "Legal", message: "Choose a document to view", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Terms of Service", style: .default) { _ in
            if let url = URL(string: "https://github.com/TruckNavPro1/TruckNavProApp/blob/main/TERMS_OF_SERVICE.md") {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "Privacy Policy", style: .default) { _ in
            if let url = URL(string: "https://github.com/TruckNavPro1/TruckNavProApp/blob/main/PRIVACY_POLICY.md") {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "EULA", style: .default) { _ in
            if let url = URL(string: "https://github.com/TruckNavPro1/TruckNavProApp/blob/main/EULA.md") {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad popover configuration to prevent crash
        if let popover = alert.popoverPresentationController {
            popover.sourceView = termsButton
            popover.sourceRect = termsButton.bounds
        }

        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSuccess(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// Associated object key for storing package reference
private var packageKey: UInt8 = 0
