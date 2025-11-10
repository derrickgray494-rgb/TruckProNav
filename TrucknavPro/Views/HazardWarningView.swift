//
//  HazardWarningView.swift
//  TruckNavPro
//

import UIKit

enum HazardType {
    case lowBridge(clearance: Double, unit: String) // clearance in feet or meters
    case weightLimit(limit: Double, unit: String) // limit in tons
    case widthRestriction(width: Double, unit: String)
    case lengthRestriction(length: Double, unit: String)
    case tunnelRestriction
    case sharpTurn
    case steepGrade(percent: Double)

    var icon: String {
        switch self {
        case .lowBridge: return "⚠️"
        case .weightLimit: return "⚠️"
        case .widthRestriction: return "⚠️"
        case .lengthRestriction: return "⚠️"
        case .tunnelRestriction: return "🚫"
        case .sharpTurn: return "↪️"
        case .steepGrade: return "⛰️"
        }
    }

    var title: String {
        switch self {
        case .lowBridge: return "LOW BRIDGE AHEAD"
        case .weightLimit: return "WEIGHT LIMIT AHEAD"
        case .widthRestriction: return "WIDTH RESTRICTION AHEAD"
        case .lengthRestriction: return "LENGTH RESTRICTION AHEAD"
        case .tunnelRestriction: return "TUNNEL RESTRICTION AHEAD"
        case .sharpTurn: return "SHARP TURN AHEAD"
        case .steepGrade: return "STEEP GRADE AHEAD"
        }
    }

    func message(truckHeight: Double?, truckWeight: Double?, truckWidth: Double?, truckLength: Double?) -> String {
        switch self {
        case .lowBridge(let clearance, let unit):
            // Convert to feet/inches for display
            let clearanceFeet = unit == "m" ? clearance * 3.28084 : clearance
            let clearanceInt = Int(clearanceFeet)
            let clearanceInches = Int((clearanceFeet - Double(clearanceInt)) * 12)

            if let height = truckHeight {
                let heightFeet = height * 3.28084
                let heightInt = Int(heightFeet)
                let heightInches = Int((heightFeet - Double(heightInt)) * 12)

                let difference = heightFeet - clearanceFeet
                let differenceInches = abs(Int(difference * 12))

                if heightFeet > clearanceFeet {
                    return "Bridge clearance: \(clearanceInt)'\(clearanceInches)\"\nYour truck height: \(heightInt)'\(heightInches)\"\nNote: \(differenceInches)\" over clearance"
                } else {
                    return "Bridge clearance: \(clearanceInt)'\(clearanceInches)\"\nYour truck height: \(heightInt)'\(heightInches)\"\nClearance available: \(differenceInches)\""
                }
            }
            return "Bridge clearance: \(clearanceInt)'\(clearanceInches)\""

        case .weightLimit(let limit, let unit):
            // Convert to pounds for display (assuming limit comes in tons)
            let limitLbs = limit * 2000 // tons to lbs

            if let weight = truckWeight {
                let weightLbs = weight * 2204.62 // metric tons to lbs
                let difference = abs(Int(weightLbs - limitLbs))

                if weightLbs > limitLbs {
                    return "Weight limit: \(Int(limitLbs)) lbs\nYour truck weight: \(Int(weightLbs)) lbs\nNote: \(difference) lbs over limit"
                } else {
                    return "Weight limit: \(Int(limitLbs)) lbs\nYour truck weight: \(Int(weightLbs)) lbs\nWeight margin: \(difference) lbs"
                }
            }
            return "Weight limit: \(Int(limitLbs)) lbs"

        case .widthRestriction(let width, let unit):
            // Convert to feet for display
            let widthFeet = unit == "m" ? width * 3.28084 : width

            if let truckW = truckWidth {
                let truckWidthFeet = truckW * 3.28084
                let differenceInches = abs(Int((truckWidthFeet - widthFeet) * 12))

                if truckWidthFeet > widthFeet {
                    return "Width restriction: \(String(format: "%.1f", widthFeet))'\nYour truck width: \(String(format: "%.1f", truckWidthFeet))'\nNote: \(differenceInches)\" over limit"
                } else {
                    return "Width restriction: \(String(format: "%.1f", widthFeet))'\nYour truck width: \(String(format: "%.1f", truckWidthFeet))'\nClearance: \(differenceInches)\""
                }
            }
            return "Width restriction: \(String(format: "%.1f", widthFeet))'"

        case .lengthRestriction(let length, let unit):
            // Convert to feet for display
            let lengthFeet = unit == "m" ? length * 3.28084 : length

            if let truckL = truckLength {
                let truckLengthFeet = truckL * 3.28084
                let differenceFeet = abs(Int(truckLengthFeet - lengthFeet))

                if truckLengthFeet > lengthFeet {
                    return "Length restriction: \(String(format: "%.1f", lengthFeet))'\nYour truck length: \(String(format: "%.1f", truckLengthFeet))'\nNote: \(differenceFeet)' over limit"
                } else {
                    return "Length restriction: \(String(format: "%.1f", lengthFeet))'\nYour truck length: \(String(format: "%.1f", truckLengthFeet))'\nClearance: \(differenceFeet)'"
                }
            }
            return "Length restriction: \(String(format: "%.1f", lengthFeet))'"

        case .tunnelRestriction:
            return "Tunnel restrictions apply - Check clearance and hazmat regulations"

        case .sharpTurn:
            return "Sharp turn ahead - Reduce speed and use caution"

        case .steepGrade(let percent):
            return "Steep grade: \(String(format: "%.1f", percent))% - Use appropriate gear"
        }
    }

    var isCritical: Bool {
        switch self {
        case .lowBridge, .weightLimit, .widthRestriction, .lengthRestriction:
            return true
        default:
            return false
        }
    }
}

struct HazardAlert {
    let type: HazardType
    let distanceInMeters: Double
    let location: String?

    var distanceDescription: String {
        // Convert to feet/miles for US display
        let distanceFeet = distanceInMeters * 3.28084

        if distanceFeet < 300 { // Less than ~100m
            return "NOW"
        } else if distanceFeet < 5280 { // Less than 1 mile
            return "in \(Int(distanceFeet)) ft"
        } else {
            let miles = distanceFeet / 5280
            return "in \(String(format: "%.1f", miles)) mi"
        }
    }
}

class HazardWarningView: UIView {

    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let distanceLabel = UILabel()
    private let dismissButton = UIButton(type: .system)

    var onDismiss: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.systemRed.withAlphaComponent(0.95)
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8

        // Icon
        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconLabel)

        // Title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Message
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)

        // Distance
        distanceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        distanceLabel.textColor = .white
        distanceLabel.textAlignment = .center
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(distanceLabel)

        // Dismiss button
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .semibold)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            dismissButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dismissButton.widthAnchor.constraint(equalToConstant: 30),
            dismissButton.heightAnchor.constraint(equalToConstant: 30),

            iconLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            distanceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            distanceLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            messageLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    func configure(with alert: HazardAlert, truckHeight: Double?, truckWeight: Double?, truckWidth: Double?, truckLength: Double?) {
        iconLabel.text = alert.type.icon
        titleLabel.text = alert.type.title
        messageLabel.text = alert.type.message(truckHeight: truckHeight, truckWeight: truckWeight, truckWidth: truckWidth, truckLength: truckLength)
        distanceLabel.text = alert.distanceDescription

        // Change color based on criticality - calm orange/yellow tones
        if alert.type.isCritical {
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.95)
        } else {
            backgroundColor = UIColor.systemYellow.withAlphaComponent(0.95)
        }

        // Animate entry
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -50)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    @objc private func dismissTapped() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -50)
        } completion: { _ in
            self.onDismiss?()
            self.removeFromSuperview()
        }
    }

    func updateDistance(_ distanceInMeters: Double) {
        let alert = HazardAlert(type: .lowBridge(clearance: 0, unit: ""), distanceInMeters: distanceInMeters, location: nil)
        distanceLabel.text = alert.distanceDescription
    }
}
