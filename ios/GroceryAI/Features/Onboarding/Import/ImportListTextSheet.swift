import SwiftUI

struct ImportListTextSheet: View {
    enum Mode: Identifiable {
        case paste
        case dictate
        case write

        var id: Self { self }

        var title: String {
            switch self {
            case .paste: "Pega tu lista"
            case .dictate: "Dicta tu lista"
            case .write: "Escribe tu lista"
            }
        }

        var hint: String? {
            switch self {
            case .paste: "Funciona con Notas, WhatsApp o Recordatorios"
            case .dictate: "Toca el micrófono del teclado para dictar"
            case .write: nil
            }
        }
    }

    let mode: Mode
    let onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var text = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-importSheet") {
            return "Leche 2 L\nHuevo 12 piezas\nArroz 1 kg"
        }
        #endif
        return ""
    }()
    @FocusState private var isFocused: Bool

    private var lineCount: Int {
        Self.itemCount(in: text)
    }

    /// Counts list entries the way the backend splits them: lines, commas
    /// (except decimal commas like "1,5 kg"), semicolons and " y ".
    static func itemCount(in text: String) -> Int {
        text.replacing(/\s+y\s+|;|,(?!\d)|\n/, with: "\n")
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                if let hint = mode.hint {
                    Label(hint, systemImage: mode == .dictate ? "mic" : "doc.on.clipboard")
                        .font(.callout)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.horizontal, 20)
                }

                if mode == .paste {
                    PasteButton(payloadType: String.self) { payloads in
                        if let pasted = payloads.first {
                            text = pasted
                        }
                    }
                    .buttonBorderShape(.capsule)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 20)
                }

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Leche 2 L\nHuevo 12 piezas\nArroz 1 kg\nPapel de baño")
                            .font(.body)
                            .foregroundStyle(colors.textSecondary.opacity(0.5))
                            .padding(.top, AppSpacing.small)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, AppSpacing.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(colors.backgroundPrimary)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: AppSpacing.small) {
                    Text(lineCount == 1 ? "1 producto" : "\(lineCount) productos")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                    GlassProminentButton("Leer mi lista") {
                        onDone(text)
                        dismiss()
                    }
                    .disabled(lineCount == 0)
                }
                .padding(.horizontal, AppSpacing.extraLarge)
                .padding(.vertical, AppSpacing.medium)
            }
            .navigationTitle(mode.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", action: dismiss.callAsFunction)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
