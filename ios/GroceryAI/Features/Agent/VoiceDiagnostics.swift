import OSLog

enum VoiceDiagnostics {
    private static let logger = Logger(
        subsystem: "com.groceryai.app",
        category: "VoiceConversation"
    )

    static func event(_ message: String) {
        logger.info("\(message, privacy: .public)")
        #if DEBUG
        print("[BarasuVoice] \(message)")
        #endif
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        #if DEBUG
        print("[BarasuVoice][ERROR] \(message)")
        #endif
    }
}
