import Foundation

enum SiteConfiguration {
    static let publicBaseURL = URL(string: "https://zeropoet.github.io/sovereign-standard")!

    static func unitURL(for unitID: Int) -> String {
        publicBaseURL
            .appendingPathComponent("unit.html")
            .absoluteString + "?id=\(unitID)"
    }
}
