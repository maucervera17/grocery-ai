import SwiftUI

struct QuestionStep<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var systemImage: String?
        var retailerID: RetailerID?
        var logoAssetName: String?
        var detail: String?

        var id: Value { value }
    }

    let step: OnboardingStep
    let title: String
    let subtitle: String
    let options: [Option]
    var allowsMultipleSelection = false
    let hasSelection: Bool
    let isSelected: (Value) -> Bool
    let onSelect: (Value) -> Void
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    var body: some View {
        scaffold {
            if allowsMultipleSelection {
                GlassProminentButton("Continuar", action: onContinue)
                    .disabled(!hasSelection)
            }
        }
    }

    private func scaffold<Footer: View>(
        @ViewBuilder footer: @escaping () -> Footer
    ) -> some View {
        OnboardingScaffold(
            step: step,
            title: title,
            subtitle: subtitle,
            onBack: onBack,
            footer: footer,
            content: {
                VStack(spacing: AppSpacing.medium) {
                    ForEach(options) { option in
                        OnboardingOptionRow(
                            title: option.title,
                            systemImage: option.systemImage,
                            retailerID: option.retailerID,
                            logoAssetName: option.logoAssetName,
                            detail: option.detail,
                            isSelected: isSelected(option.value)
                        ) {
                            select(option.value)
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: sensoryTrigger)
            }
        )
    }

    private var sensoryTrigger: Int {
        options.filter { isSelected($0.value) }.count
    }

    private func select(_ value: Value) {
        onSelect(value)
    }
}
