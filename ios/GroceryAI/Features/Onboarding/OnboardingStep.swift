import Foundation

enum OnboardingStep: String, Hashable, Sendable {
    case welcome
    case householdSize
    case frequency
    case usualStore
    case postalCode
    case comparisonStores
    case access
    case planLoader
    case basketResult
    case importMethod
    case importReview
    case paywall
}

extension OnboardingStep {
    static let progressOrder: [OnboardingStep] = [
        .householdSize, .frequency, .usualStore, .postalCode,
        .comparisonStores, .access, .basketResult, .importMethod, .importReview
    ]

    static let questionSteps: [OnboardingStep] = [
        .householdSize, .frequency, .usualStore, .postalCode, .comparisonStores
    ]

    var progressIndex: Int? {
        Self.progressOrder.firstIndex(of: self)
    }

    var progressFraction: Double {
        guard let progressIndex else { return 0 }
        return Double(progressIndex + 1) / Double(Self.progressOrder.count)
    }

    var accessibilityStepAnnouncement: String? {
        guard let progressIndex else { return nil }
        return "Paso \(progressIndex + 1) de \(Self.progressOrder.count)"
    }

    var showsBackButton: Bool {
        switch self {
        case .welcome, .planLoader, .paywall:
            false
        default:
            true
        }
    }
}
