//
//  CustomSearchBar.swift
//  TruckNavPro
//

import UIKit
import CoreLocation

// MARK: - Quick Category

enum TruckQuickCategory: String, CaseIterable {
    case truckStops = "Truck Stops"
    case fuel = "Fuel"
    case restAreas = "Rest Areas"
    case weighStations = "Weigh Stations"
    case parking = "Parking"
    case restaurants = "Restaurants"

    var icon: String {
        switch self {
        case .truckStops: return "fuelpump.circle.fill"
        case .fuel: return "fuelpump.fill"
        case .restAreas: return "bed.double.fill"
        case .weighStations: return "scalemass.fill"
        case .parking: return "parkingsign.circle.fill"
        case .restaurants: return "fork.knife.circle.fill"
        }
    }

    var tomTomCategory: TomTomSearchService.TruckCategory {
        switch self {
        case .truckStops: return .truckStop
        case .fuel: return .fuelStation
        case .restAreas: return .restArea
        case .weighStations: return .weighStation
        case .parking: return .truckParking
        case .restaurants: return .restaurant
        }
    }
}

// MARK: - Custom Search Bar with Liquid Glass Effect

protocol CustomSearchBarDelegate: AnyObject {
    func searchBarDidBeginEditing(_ searchBar: CustomSearchBar)
    func searchBar(_ searchBar: CustomSearchBar, textDidChange searchText: String)
    func searchBarSearchButtonClicked(_ searchBar: CustomSearchBar)
    func searchBar(_ searchBar: CustomSearchBar, didSelectCategory category: TruckQuickCategory)
}

class CustomSearchBar: UIView {

    weak var delegate: CustomSearchBarDelegate?

    // MARK: - UI Components

    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.clipsToBounds = true
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let searchContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemFill.withAlphaComponent(0.3)
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let searchIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        imageView.image = UIImage(systemName: "magnifyingglass", withConfiguration: config)
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let textField: UITextField = {
        let field = UITextField()
        field.placeholder = "Search destinations, truck stops..."
        field.font = .systemFont(ofSize: 16, weight: .regular)
        field.textColor = .label
        field.tintColor = .systemBlue
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.clearButtonMode = .whileEditing
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let categoryScrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    private let categoryStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fill
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupCategories()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupCategories()
    }

    // MARK: - Setup

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        // Add blur background
        addSubview(blurView)

        // Add search container to blur's content view
        blurView.contentView.addSubview(searchContainerView)

        // Add search icon and text field to search container
        searchContainerView.addSubview(searchIcon)
        searchContainerView.addSubview(textField)

        // Add category scroll view
        blurView.contentView.addSubview(categoryScrollView)
        categoryScrollView.addSubview(categoryStackView)

        // Text field delegate
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        // Shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12

        NSLayoutConstraint.activate([
            // Blur view fills the entire custom search bar
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Search container
            searchContainerView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 12),
            searchContainerView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
            searchContainerView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -12),
            searchContainerView.heightAnchor.constraint(equalToConstant: 48),

            // Search icon
            searchIcon.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            // Text field
            textField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -12),
            textField.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),

            // Category scroll view
            categoryScrollView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 8),
            categoryScrollView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
            categoryScrollView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -12),
            categoryScrollView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -12),
            categoryScrollView.heightAnchor.constraint(equalToConstant: 40),

            // Category stack view
            categoryStackView.topAnchor.constraint(equalTo: categoryScrollView.topAnchor),
            categoryStackView.leadingAnchor.constraint(equalTo: categoryScrollView.leadingAnchor),
            categoryStackView.trailingAnchor.constraint(equalTo: categoryScrollView.trailingAnchor),
            categoryStackView.bottomAnchor.constraint(equalTo: categoryScrollView.bottomAnchor),
            categoryStackView.heightAnchor.constraint(equalTo: categoryScrollView.heightAnchor)
        ])
    }

    private func setupCategories() {
        for category in TruckQuickCategory.allCases {
            let button = createCategoryButton(for: category)
            categoryStackView.addArrangedSubview(button)
        }
    }

    private func createCategoryButton(for category: TruckQuickCategory) -> UIButton {
        let button = UIButton(type: .system)

        // Icon
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let icon = UIImage(systemName: category.icon, withConfiguration: config)
        button.setImage(icon, for: .normal)

        // Title
        button.setTitle(category.rawValue, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)

        // Styling
        button.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.5)
        button.tintColor = .label
        button.layer.cornerRadius = 20
        button.layer.cornerCurve = .continuous

        // Layout
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Action
        button.tag = TruckQuickCategory.allCases.firstIndex(of: category) ?? 0
        button.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)

        return button
    }

    // MARK: - Actions

    @objc private func textFieldDidChange() {
        delegate?.searchBar(self, textDidChange: textField.text ?? "")
    }

    @objc private func categoryButtonTapped(_ sender: UIButton) {
        let category = TruckQuickCategory.allCases[sender.tag]

        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }

        delegate?.searchBar(self, didSelectCategory: category)
    }
}

// MARK: - UITextFieldDelegate

extension CustomSearchBar: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        delegate?.searchBarDidBeginEditing(self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        delegate?.searchBarSearchButtonClicked(self)
        return true
    }
}
