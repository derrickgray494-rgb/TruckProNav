//
//  SettingsViewController.swift
//  TruckNavPro
//

import UIKit

// MARK: - Settings Change Delegate

protocol SettingsViewControllerDelegate: AnyObject {
    func settingsDidChange()
    func mapStyleDidChange(to style: TruckSettings.MapStyle)
}

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    weak var delegate: SettingsViewControllerDelegate?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum SettingsSection: Int, CaseIterable {
        case truck
        case navigation
        case map
        case search
        case system

        var title: String {
            switch self {
            case .truck: return "Truck Settings"
            case .navigation: return "Navigation"
            case .map: return "Map Display"
            case .search: return "Search"
            case .system: return "System"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Settings"
        view.backgroundColor = .systemGroupedBackground

        setupTableView()
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissSettings))
        navigationItem.rightBarButtonItem = closeButton
    }

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingCell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(ValueTableViewCell.self, forCellReuseIdentifier: "ValueCell")

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingsSection = SettingsSection(rawValue: section) else { return 0 }

        switch settingsSection {
        case .truck: return 3
        case .navigation: return 4
        case .map: return 3
        case .search: return 2
        case .system: return 4
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingsSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .truck:
            return configureTruckCell(for: indexPath)
        case .navigation:
            return configureNavigationCell(for: indexPath)
        case .map:
            return configureMapCell(for: indexPath)
        case .search:
            return configureSearchCell(for: indexPath)
        case .system:
            return configureSystemCell(for: indexPath)
        }
    }

    // MARK: - Cell Configuration

    private func configureTruckCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! ValueTableViewCell
            cell.textLabel?.text = "Truck Height"
            cell.valueLabel.text = TruckSettings.formattedHeight()
            cell.accessoryType = .disclosureIndicator
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! ValueTableViewCell
            cell.textLabel?.text = "Truck Width"
            cell.valueLabel.text = TruckSettings.formattedWidth()
            cell.accessoryType = .disclosureIndicator
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! ValueTableViewCell
            cell.textLabel?.text = "Truck Weight"
            cell.valueLabel.text = TruckSettings.formattedWeight()
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            return UITableViewCell()
        }
    }

    private func configureNavigationCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! ValueTableViewCell
            cell.textLabel?.text = "Voice Volume"
            cell.valueLabel.text = "\(TruckSettings.voiceVolume)%"
            cell.accessoryType = .disclosureIndicator
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Avoid Toll Roads"
            cell.switchControl.isOn = TruckSettings.avoidTolls
            cell.switchControl.tag = 1001
            cell.switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Avoid Highways"
            cell.switchControl.isOn = TruckSettings.avoidHighways
            cell.switchControl.tag = 1002
            cell.switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
            return cell
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Avoid Ferries"
            cell.switchControl.isOn = TruckSettings.avoidFerries
            cell.switchControl.tag = 1003
            cell.switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
            return cell
        default:
            return UITableViewCell()
        }
    }

    private func configureMapCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Hazmat Cargo"
            cell.switchControl.isOn = TruckSettings.hazmat
            cell.switchControl.tag = 2001
            cell.switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Imperial Units"
            cell.switchControl.isOn = TruckSettings.useImperialUnits
            cell.switchControl.tag = 2002
            cell.switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! ValueTableViewCell
            cell.textLabel?.text = "Map Style"
            cell.valueLabel.text = TruckSettings.mapStyle.rawValue
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            return UITableViewCell()
        }
    }

    private func configureSearchCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath) as! ValueTableViewCell
            cell.textLabel?.text = "POI Results"
            cell.valueLabel.text = "10"
            cell.accessoryType = .disclosureIndicator
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Show Annotations"
            cell.switchControl.isOn = true
            return cell
        default:
            return UITableViewCell()
        }
    }

    private func configureSystemCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath)

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Location Services"
            cell.accessoryType = .disclosureIndicator
        case 1:
            cell.textLabel?.text = "Notifications"
            cell.accessoryType = .disclosureIndicator
        case 2:
            cell.textLabel?.text = "Privacy"
            cell.accessoryType = .disclosureIndicator
        case 3:
            cell.textLabel?.text = "About"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = SettingsSection(rawValue: indexPath.section) else { return }

        switch section {
        case .truck:
            handleTruckSetting(at: indexPath.row)
        case .navigation:
            handleNavigationSetting(at: indexPath.row)
        case .map:
            handleMapSetting(at: indexPath.row)
        case .search:
            handleSearchSetting(at: indexPath.row)
        case .system:
            handleSystemSetting(at: indexPath.row)
        }
    }

    private func handleTruckSetting(at row: Int) {
        switch row {
        case 0:
            print("⚙️ Adjust truck height")
            showTruckDimensionPicker(type: "Height", currentValue: "13'6\"")
        case 1:
            print("⚙️ Adjust truck width")
            showTruckDimensionPicker(type: "Width", currentValue: "8 ft")
        case 2:
            print("⚙️ Adjust truck weight")
            showTruckDimensionPicker(type: "Weight", currentValue: "80,000 lbs")
        default:
            break
        }
    }

    private func handleNavigationSetting(at row: Int) {
        switch row {
        case 0:
            print("⚙️ Adjust voice volume")
            showVoiceVolumePicker()
        default:
            break
        }
    }

    private func showVoiceVolumePicker() {
        let alert = UIAlertController(title: "Voice Volume", message: "Adjust navigation voice guidance volume", preferredStyle: .actionSheet)
        for volume in [0, 25, 50, 75, 100] {
            let action = UIAlertAction(title: "\(volume)%", style: .default) { [weak self] _ in
                guard let self = self else { return }
                TruckSettings.voiceVolume = volume
                print("💾 Voice volume set to: \(volume)%")
                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                self.delegate?.settingsDidChange()
            }
            if volume == TruckSettings.voiceVolume {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func handleMapSetting(at row: Int) {
        switch row {
        case 2:
            print("⚙️ Change map style")
            showMapStylePicker()
        default:
            break
        }
    }

    private func handleSearchSetting(at row: Int) {
        switch row {
        case 0:
            print("⚙️ Adjust POI result count")
            showPOIResultPicker()
        default:
            break
        }
    }

    private func handleSystemSetting(at row: Int) {
        switch row {
        case 0:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
                print("⚙️ Opening Location Services settings")
            }
        case 1:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
                print("⚙️ Opening Notifications settings")
            }
        case 2:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
                print("⚙️ Opening Privacy settings")
            }
        case 3:
            showAboutView()
        default:
            break
        }
    }

    // MARK: - Switch Handler

    @objc private func switchValueChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 1001: // Avoid Tolls
            TruckSettings.avoidTolls = sender.isOn
            print("💾 Avoid tolls: \(sender.isOn)")
        case 1002: // Avoid Highways
            TruckSettings.avoidHighways = sender.isOn
            print("💾 Avoid highways: \(sender.isOn)")
        case 1003: // Avoid Ferries
            TruckSettings.avoidFerries = sender.isOn
            print("💾 Avoid ferries: \(sender.isOn)")
        case 2001: // Hazmat
            TruckSettings.hazmat = sender.isOn
            print("💾 Hazmat cargo: \(sender.isOn)")
        case 2002: // Imperial Units
            TruckSettings.useImperialUnits = sender.isOn
            print("💾 Imperial units: \(sender.isOn)")
            // Reload truck settings to update display format
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
        default:
            break
        }

        delegate?.settingsDidChange()
    }

    // MARK: - Helper Methods

    private func showTruckDimensionPicker(type: String, currentValue: String) {
        let alert = UIAlertController(title: "Truck \(type)", message: "Enter value in meters\nCurrent: \(currentValue)", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Enter \(type.lowercased()) in meters"
            textField.keyboardType = .decimalPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self, let text = alert.textFields?.first?.text, let value = Double(text) else { return }

            switch type {
            case "Height":
                TruckSettings.height = value
                print("💾 Saved truck height: \(value)m")
            case "Width":
                TruckSettings.width = value
                print("💾 Saved truck width: \(value)m")
            case "Weight":
                TruckSettings.weight = value
                print("💾 Saved truck weight: \(value)t")
            default:
                break
            }

            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            self.delegate?.settingsDidChange()
        })
        present(alert, animated: true)
    }

    private func showMapStylePicker() {
        let alert = UIAlertController(title: "Map Style", message: "Select map appearance", preferredStyle: .actionSheet)

        for style in [TruckSettings.MapStyle.auto, .day, .night] {
            let action = UIAlertAction(title: style.rawValue, style: .default) { [weak self] _ in
                guard let self = self else { return }
                TruckSettings.mapStyle = style
                print("💾 Map style changed to: \(style.rawValue)")

                // Reload map section to update display
                self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)

                // Notify delegate for immediate map update
                self.delegate?.mapStyleDidChange(to: style)
            }
            if style == TruckSettings.mapStyle {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showPOIResultPicker() {
        let alert = UIAlertController(title: "POI Results", message: "Number of results to show", preferredStyle: .actionSheet)
        for count in [5, 10, 15, 20] {
            alert.addAction(UIAlertAction(title: "\(count) results", style: .default) { _ in
                print("💾 Set POI results to \(count)")
                UserDefaults.standard.set(count, forKey: "POIResultCount")
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showAboutView() {
        let alert = UIAlertController(title: "TruckNav Pro", message: "Version 1.0.0\n\nTruck-specific navigation powered by Mapbox\n\n© 2025", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Custom Cells

class SwitchTableViewCell: UITableViewCell {
    let switchControl = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryView = switchControl
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ValueTableViewCell: UITableViewCell {
    let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        valueLabel.textColor = .secondaryLabel
        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
