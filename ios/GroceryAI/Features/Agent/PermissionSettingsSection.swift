import AVFAudio
import CoreLocation
import SwiftUI
import UIKit

struct PermissionSettingsSection: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = PermissionSettingsModel()

    var body: some View {
        Section {
            LabeledContent {
                Button(locationActionTitle, action: handleLocationPermission)
                    .disabled(locationActionIsDisabled)
            } label: {
                Label("Ubicación", systemImage: "location")
            }

            LabeledContent {
                Button(microphoneActionTitle, action: handleMicrophonePermission)
                    .disabled(microphoneActionIsDisabled)
            } label: {
                Label("Micrófono", systemImage: "microphone")
            }
        } header: {
            Text("Permisos")
        } footer: {
            Text("La ubicación permite buscar precios cercanos. El micrófono permite agregar productos por voz.")
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                model.refresh()
            }
        }
    }

    private var locationActionTitle: String {
        switch model.locationStatus {
        case .notDetermined:
            "Permitir"
        case .authorizedAlways, .authorizedWhenInUse:
            "Permitido"
        case .denied:
            "Abrir Ajustes"
        case .restricted:
            "Restringido"
        @unknown default:
            "No disponible"
        }
    }

    private var locationActionIsDisabled: Bool {
        switch model.locationStatus {
        case .notDetermined, .denied:
            false
        default:
            true
        }
    }

    private var microphoneActionTitle: String {
        switch model.microphoneStatus {
        case .undetermined:
            "Permitir"
        case .granted:
            "Permitido"
        case .denied:
            "Abrir Ajustes"
        @unknown default:
            "No disponible"
        }
    }

    private var microphoneActionIsDisabled: Bool {
        model.microphoneStatus == .granted
    }

    private func handleLocationPermission() {
        if model.locationStatus == .notDetermined {
            model.requestLocation()
        } else {
            openApplicationSettings()
        }
    }

    private func handleMicrophonePermission() {
        if model.microphoneStatus == .undetermined {
            model.requestMicrophone()
        } else {
            openApplicationSettings()
        }
    }

    private func openApplicationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
