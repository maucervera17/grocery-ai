import Foundation

enum OnboardingStep: String, Hashable, Sendable {
    case welcome
    case intro
    case householdSize
    case frequency
    case monthlySpend
    case usualStores
    case compareHabit
    case insight
    case goals
    case painPoints
    case listHabit
    case postalCode
    case planLoader
    case savingsResult
    case benefits
    case access
    case importMethod
    case importReview
    case demoPick
    case demoComparing
    case demoResult
    case paywall
}

extension OnboardingStep {
    static let progressOrder: [OnboardingStep] = [
        .intro, .householdSize, .frequency, .monthlySpend, .usualStores,
        .compareHabit, .insight, .goals, .painPoints, .listHabit,
        .postalCode, .savingsResult, .benefits, .access, .importMethod,
        .importReview, .demoPick, .demoResult
    ]

    static let questionSteps: [OnboardingStep] = [
        .householdSize, .frequency, .monthlySpend, .usualStores,
        .compareHabit, .goals, .painPoints, .listHabit
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
        case .welcome, .planLoader, .savingsResult, .demoComparing, .demoResult, .paywall:
            false
        default:
            true
        }
    }
}
