import MapKit
import SwiftUI

struct PostalCodeStep: View {
    @Binding var postalCode: String
    let onContinue: (String) -> Void
    let onSkip: () -> Void
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var locator = PostalCodeLocator()
    @State private var nearby = NearbyStoresFinder()
    @State private var mapPosition: MapCameraPosition = .region(Self.genericRegion)
    @State private var showsManualField = false
    @FocusState private var isFieldFocused: Bool

    private static let genericRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.415, longitude: -99.165),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )

    private var postalCodeCenter: CLLocationCoordinate2D? {
        if case .loaded(let latitude, let longitude, _) = nearby.state {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return nil
    }

    private var nearbyStores: [NearbyStore] {
        if case .loaded(_, _, let stores) = nearby.state { return stores }
        return []
    }

    private var hasCode: Bool {
        Self.isValid(postalCode)
    }

    /// Mexican postal codes run from 01000 to 99999.
    static func isValid(_ code: String) -> Bool {
        guard code.count == 5, code.allSatisfy(\.isASCII), let value = Int(code) else { return false }
        return value >= 1000
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .postalCode,
            title: "¿Cuál es tu código postal?",
            subtitle: "Lo guardamos para tus búsquedas. Por ahora comparamos precios publicados en línea, no los de una sucursal.",
            onBack: onBack,
            layout: .centered,
            footer: {
            VStack(spacing: AppSpacing.small) {
                if hasCode {
                    GlassProminentButton("Continuar") {
                        onContinue(postalCode)
                    }
                } else {
                    GlassProminentButton(
                        locator.isLoading ? "Buscando…" : "Usar mi ubicación",
                        systemImage: "location.fill"
                    ) {
                        locator.request()
                        isFieldFocused = false
                    }
                    .disabled(locator.isLoading)
                }

                if !hasCode && !showsManualField {
                    Button("Escribir código postal") {
                        showsManualField = true
                        isFieldFocused = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.brandPrimary)
                    .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget)
                    .contentShape(.rect)
                }

                if !hasCode {
                    Button("Ahora no", action: onSkip)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget)
                        .contentShape(.rect)
                }
            }
            },
            content: {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if nearby.state != .failed {
                    mapHero(colors: colors)
                }
                nearbyStatus(colors: colors)

                if hasCode && !showsManualField {
                    HStack(spacing: AppSpacing.medium) {
                        Label("CP \(postalCode)", systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(colors.statusSuccess)
                        Spacer(minLength: 0)
                        Button("Cambiar") {
                            showsManualField = true
                            isFieldFocused = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.brandPrimary)
                        .frame(minWidth: AppControlSize.minimumTapTarget, minHeight: AppControlSize.minimumTapTarget)
                        .contentShape(.rect)
                        .accessibilityLabel("Cambiar código postal")
                    }
                } else {
                    if let message = locator.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                    }
                    if postalCode.count == 5 && !hasCode {
                        Label("Ese código postal no existe. Revisa los 5 dígitos.", systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(colors.statusError)
                    }
                    if showsManualField {
                        TextField("Código postal", text: $postalCode)
                            .textContentType(.postalCode)
                            .keyboardType(.numberPad)
                            .focused($isFieldFocused)
                            .onChange(of: postalCode) {
                                postalCode = String(postalCode.filter(\.isNumber).prefix(5))
                            }
                            .padding(.horizontal, AppSpacing.large)
                            .padding(.vertical, AppSpacing.large)
                            .background(colors.cellBackground, in: .rect(cornerRadius: 22, style: .continuous))
                            .accessibilityHint("Ingresa los cinco dígitos")
                    }
                }
            }
            }
        )
        #if DEBUG
        .onAppear {
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-postalCode"),
               ProcessInfo.processInfo.arguments.indices.contains(i + 1) {
                postalCode = ProcessInfo.processInfo.arguments[i + 1]
            }
        }
        #endif
        .onChange(of: locator.postalCode) {
            if let code = locator.postalCode {
                postalCode = code
                showsManualField = false
            }
        }
        .onChange(of: postalCode, initial: true) {
            if hasCode {
                nearby.find(postalCode: postalCode)
            } else {
                nearby.reset()
                mapPosition = .region(Self.genericRegion)
            }
        }
        .onChange(of: nearby.state) {
            if case .loaded(let latitude, let longitude, let stores) = nearby.state {
                let farthest = stores.map(\.distance).max() ?? NearbyStoresFinder.searchRadius / 2
                let span = max(farthest * 2.6, 1_500)
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                        latitudinalMeters: span,
                        longitudinalMeters: span
                    ))
                }
            }
        }
        .onDisappear {
            locator.cancel()
            nearby.reset()
        }
    }

    @ViewBuilder
    private func mapHero(colors: AppThemeColors) -> some View {
        Map(position: $mapPosition) {
            if let center = postalCodeCenter {
                Annotation("", coordinate: center) {
                    centerDot(colors: colors)
                }
            }
            ForEach(nearbyStores) { branch in
                Annotation("", coordinate: branch.coordinate) {
                    Image(branch.store.logoAssetName ?? "")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 24)
                        .frame(width: 40, height: 30)
                        .background(.white, in: .rect(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(height: 240)
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .mask(alignment: .bottom) {
            LinearGradient(
                colors: [.black, .black.opacity(0)],
                startPoint: .init(x: 0.5, y: 0.82),
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func nearbyStatus(colors: AppThemeColors) -> some View {
        switch nearby.state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                Text("Buscando sucursales cerca de tu CP…")
            }
            .font(.footnote)
            .foregroundStyle(colors.textSecondary)
            .accessibilityElement(children: .combine)
        case .loaded(_, _, let stores):
            Label(NearbyStoresFinder.summary(for: stores), systemImage: "mappin.and.ellipse")
                .font(.footnote)
                .foregroundStyle(colors.textSecondary)
        case .failed:
            Label("No pudimos ubicar tu CP en el mapa. Igual comparamos precios en línea.", systemImage: "map")
                .font(.footnote)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private func centerDot(colors: AppThemeColors) -> some View {
        Circle()
            .fill(colors.brandPrimary)
            .frame(width: 16, height: 16)
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: 3)
            }
    }
}
