import PhotosUI
import SwiftUI

struct ImportMethodStep: View {
    let model: OnboardingModel
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var textSheetMode: ImportListTextSheet.Mode?
    @State private var isShowingCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingPhotoPicker = false
    @State private var importTask: Task<Void, Never>?

    private let recognizer = ListTextRecognizer()

    private var recommended: ImportMethod {
        ImportMethod(listHabit: model.answers.listHabit)
    }

    var body: some View {
        OnboardingScaffold(
            step: .importMethod,
            title: "Trae tu lista del súper",
            subtitle: "La usaremos para tu prueba. Puedes editarla después.",
            onBack: onBack,
            footer: {
            VStack(spacing: AppSpacing.small) {
                GlassProminentButton("Continuar", action: continueWithSelection)
                    .disabled(model.answers.importMethod == nil || model.isImportingList)
                Button("Ahora no") {
                    model.useSuggestedList()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.colors(for: colorScheme).textSecondary)
                .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget)
                .contentShape(.rect)
            }
            },
            content: {
            VStack(spacing: AppSpacing.medium) {
                ForEach(ImportMethod.allCases, id: \.self) { method in
                    OnboardingOptionRow(
                        title: method.title,
                        systemImage: method.systemImage,
                        badge: method == recommended ? "Recomendado" : nil,
                        isSelected: model.answers.importMethod == method
                    ) {
                        model.answers.importMethod = method
                    }
                }
            }
            }
        )
        .sheet(item: $textSheetMode) { mode in
            ImportListTextSheet(mode: mode) { text in
                importText(text)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-importSheet") {
                textSheetMode = .paste
            }
        }
        #endif
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraImagePicker { image in
                importImage(image)
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $photoItem,
            matching: .images
        )
        .onChange(of: photoItem) {
            guard let photoItem else { return }
            importTask = Task {
                if let data = try? await photoItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    importImage(image)
                }
                self.photoItem = nil
            }
        }
    }

    private func continueWithSelection() {
        guard let method = model.answers.importMethod else { return }
        if method != .suggested {
            OnboardingEvent.importMethod(method).log()
        }
        switch method {
        case .camera:
            if CameraImagePicker.isAvailable {
                isShowingCamera = true
            } else {
                photoItem = nil
                presentLibraryPicker()
            }
        case .paste:
            textSheetMode = .paste
        case .dictate:
            textSheetMode = .dictate
        case .write:
            textSheetMode = .write
        case .suggested:
            model.useSuggestedList()
        }
    }

    private func presentLibraryPicker() {
        isShowingPhotoPicker = true
    }

    private func importText(_ text: String) {
        importTask = Task {
            await model.importList(from: text)
        }
    }

    private func importImage(_ image: UIImage) {
        importTask = Task {
            do {
                let text = try await recognizer.recognizeText(in: image)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.showUnreadablePhoto()
                } else {
                    await model.importList(from: text)
                }
            } catch {
                model.showUnreadablePhoto()
            }
        }
    }
}
