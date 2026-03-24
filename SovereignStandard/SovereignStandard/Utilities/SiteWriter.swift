import Foundation

struct SiteWriter {
    func write(units: [Int], root: URL) throws {
        let manifest = SiteManifest(units: units)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(manifest)
        try data.write(to: root.appendingPathComponent("units.json"))
    }
}

private struct SiteManifest: Encodable {
    let units: [Int]
}
