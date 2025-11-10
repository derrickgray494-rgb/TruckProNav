//
//  SearchResultsTableView.swift
//  TruckNavPro
//

import UIKit
import CoreLocation

class SearchResultsTableView: UIView {

    // MARK: - Properties

    var onResultSelected: ((TomTomSearchService.TruckSearchResult) -> Void)?

    private var results: [TomTomSearchService.TruckSearchResult] = []
    private var userLocation: CLLocationCoordinate2D?

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear  // Transparent to show blur background
        table.separatorStyle = .singleLine
        table.separatorColor = .separator
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        table.isOpaque = false
        return table
    }()

    private let blurBackground: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        addSubview(blurBackground)
        addSubview(headerLabel)
        addSubview(tableView)

        tableView.delegate = self
        tableView.dataSource = self

        // Styling with rounded corners
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        clipsToBounds = false

        // Make blur background clip to bounds for rounded corners
        blurBackground.layer.cornerRadius = 16
        blurBackground.layer.cornerCurve = .continuous
        blurBackground.clipsToBounds = true

        NSLayoutConstraint.activate([
            blurBackground.topAnchor.constraint(equalTo: topAnchor),
            blurBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public Methods

    func updateResults(_ results: [TomTomSearchService.TruckSearchResult], userLocation: CLLocationCoordinate2D?, query: String? = nil, category: String? = nil) {
        self.results = results
        self.userLocation = userLocation

        if let category = category {
            headerLabel.text = "\(results.count) \(category) nearby"
        } else if let query = query {
            headerLabel.text = "\(results.count) results for '\(query)'"
        } else {
            headerLabel.text = "\(results.count) results"
        }

        tableView.reloadData()

        // Force layout update
        layoutIfNeeded()

        // Debug output
        print("📋 Results table updated: \(results.count) results")
        print("📏 Table frame: \(self.frame)")
        print("👁️ Table hidden: \(self.isHidden)")
        print("🎨 Table background: \(self.backgroundColor?.description ?? "nil")")
    }

    func clearResults() {
        results = []
        tableView.reloadData()
    }
}

// MARK: - UITableViewDelegate & DataSource

extension SearchResultsTableView: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
            return UITableViewCell()
        }

        let result = results[indexPath.row]

        // Calculate distance if user location available
        var distanceText: String?
        if let userLoc = userLocation {
            let distance = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                .distance(from: CLLocation(latitude: result.coordinate.latitude, longitude: result.coordinate.longitude))

            let miles = distance * 0.000621371
            if miles < 0.1 {
                distanceText = "< 0.1 mi"
            } else if miles < 10 {
                distanceText = String(format: "%.1f mi", miles)
            } else {
                distanceText = String(format: "%.0f mi", miles)
            }
        }

        cell.configure(with: result, distance: distanceText)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let result = results[indexPath.row]
        onResultSelected?(result)
    }
}

// MARK: - Search Result Cell

class SearchResultCell: UITableViewCell {

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let distanceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        imageView.image = UIImage(systemName: "mappin.circle.fill", withConfiguration: config)
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(addressLabel)
        contentView.addSubview(distanceLabel)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: distanceLabel.leadingAnchor, constant: -8),

            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            addressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            addressLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            distanceLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            distanceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            distanceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }

    func configure(with result: TomTomSearchService.TruckSearchResult, distance: String?) {
        nameLabel.text = result.name
        addressLabel.text = result.address
        distanceLabel.text = distance
    }
}
