import SwiftUI

struct EmptyStateView: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let message: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    init(
        title: LocalizedStringKey,
        systemImage: String,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                PrimaryButton(actionTitle, expandsHorizontally: false, action: action)
            }
        }
    }
}
