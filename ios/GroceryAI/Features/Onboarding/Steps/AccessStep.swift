import SwiftUI

struct AccessStep: View {
    let model: OnboardingModel
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var password = ""
    @FocusState private var isFieldFocused: Bool

    private var canSubmit: Bool {
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .access,
            title: "Ingresa tu contraseña de acceso",
            subtitle: "Barasu está en acceso anticipado. Con tu contraseña leemos tu lista y comparamos precios reales.",
            onBack: onBack,
            footer: {
            VStack(spacing: AppSpacing.small) {
                if model.hasVerifiedAccess {
                    GlassProminentButton("Continuar") {
                        model.advance(from: .access)
                    }
                } else {
                    GlassProminentButton("Continuar", isLoading: model.isVerifyingAccess, action: submit)
                        .disabled(!canSubmit)

                    Button("No tengo contraseña", action: model.skipAccess)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget)
                        .contentShape(.rect)
                        .disabled(model.isVerifyingAccess)
                }
            }
            },
            content: {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                if model.hasVerifiedAccess {
                    Label("Acceso verificado", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(colors.statusSuccess)
                } else {
                    SecureField("Contraseña de acceso", text: $password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)
                        .focused($isFieldFocused)
                        .onSubmit(submit)
                        .onChange(of: password) {
                            model.accessErrorMessage = nil
                        }
                        .disabled(model.isVerifyingAccess)
                        .padding(.horizontal, AppSpacing.large)
                        .padding(.vertical, AppSpacing.large)
                        .background(colors.cellBackground, in: .rect(cornerRadius: 22, style: .continuous))
                        .overlay {
                            if model.accessErrorMessage != nil {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(colors.statusError, lineWidth: 1)
                            }
                        }

                    if let message = model.accessErrorMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(colors.statusError)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.updatesFrequently)
                    }

                    Label("Se guarda solo en el llavero de este iPhone. Puedes cambiarla después en Ajustes.", systemImage: "lock")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            }
        )
        .onAppear {
            if !model.hasVerifiedAccess { isFieldFocused = true }
        }
        .onChange(of: model.accessErrorMessage) {
            if let message = model.accessErrorMessage {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        Task { await model.submitAccess(password) }
    }
}
