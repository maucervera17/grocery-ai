import Foundation
import OSLog

enum OnboardingEvent {
    case stepViewed(OnboardingStep)
    case answer(step: OnboardingStep, value: String)
    case accessVerified
    case accessSkipped
    case importMethod(ImportMethod)
    case demoFinished(savingsCents: Int)
    case demoFailed
    case paywallViewed
    case subscribed(SubscriptionPlanID)
    case finished

    private static let logger = Logger(
        subsystem: "com.groceryai.app",
        category: "Onboarding"
    )

    func log() {
        switch self {
        case .stepViewed(let step):
            Self.logger.info("onboarding.step_viewed \(step.rawValue, privacy: .public)")
        case .answer(let step, let value):
            Self.logger.info("onboarding.answer \(step.rawValue, privacy: .public)=\(value, privacy: .public)")
        case .accessVerified:
            Self.logger.info("onboarding.access verified")
        case .accessSkipped:
            Self.logger.info("onboarding.access skipped")
        case .importMethod(let method):
            Self.logger.info("onboarding.import_method \(method.rawValue, privacy: .public)")
        case .demoFinished(let savingsCents):
            Self.logger.info("onboarding.demo_result savings=\(savingsCents)")
        case .demoFailed:
            Self.logger.info("onboarding.demo_result failed")
        case .paywallViewed:
            Self.logger.info("onboarding.paywall_viewed")
        case .subscribed(let plan):
            Self.logger.info("onboarding.subscribed \(plan.rawValue, privacy: .public)")
        case .finished:
            Self.logger.info("onboarding.finished")
        }
    }
}
