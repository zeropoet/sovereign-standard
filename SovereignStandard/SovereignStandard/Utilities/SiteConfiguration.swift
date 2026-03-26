import Foundation

enum SiteConfiguration {
    static let publicBaseURL = URL(string: "https://sovereignstandard.co")!

    static func unitURL(for unitID: Int) -> String {
        publicBaseURL
            .appendingPathComponent("unit.html")
            .absoluteString + "?id=\(unitID)"
    }
}
