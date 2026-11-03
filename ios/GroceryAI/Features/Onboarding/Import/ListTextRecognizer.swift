import UIKit
import Vision

struct ListTextRecognizer {
    func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw RecognizerError.invalidImage
        }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.Language(identifier: "es-ES")]

        let observations = try await request.perform(on: cgImage)
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    enum RecognizerError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            "No pude procesar la imagen."
        }
    }
}
