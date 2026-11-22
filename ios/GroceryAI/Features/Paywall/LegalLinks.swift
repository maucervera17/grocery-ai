import Foundation

enum LegalLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Served from `web/privacidad.html` on the Vercel web deployment.
    static let privacy = URL(string: "https://barasu-web.vercel.app/privacidad.html")!
}
