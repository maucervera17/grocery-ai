import OSLog

enum ComparisonDiagnostics {
    private static let logger = Logger(
        subsystem: "com.groceryai.app",
        category: "Comparison"
    )

    static func event(_ message: String) {
        logger.info("\(message, privacy: .public)")
        #if DEBUG
        print("[BarasuComparison] \(message)")
        #endif
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        #if DEBUG
        print("[BarasuComparison][ERROR] \(message)")
        #endif
    }
}
