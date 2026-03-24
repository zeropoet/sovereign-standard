import Foundation
import FoldKernel

struct OutputWriter {
    private let qrCode = QRCode()
    private let creationDateFormatter = ISO8601DateFormatter()

    init() {
        creationDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func write(unit: UnitOutput, outputRoot: URL) throws {
        let unitDirectory = outputRoot.appendingPathComponent(String(unit.unitID), isDirectory: true)
        let dataURL = unitDirectory.appendingPathComponent("data.json")

        try FileManager.default.createDirectory(
            at: unitDirectory,
            withIntermediateDirectories: true
        )

        let qrSVG = try qrCode.exportSVG(url: SiteConfiguration.unitURL(for: unit.unitID))
        let frontSVG = LaserLayout.frontSVG(unit: unit)
        let backSVG = LaserLayout.backSVG(unit: unit, qrSVG: qrSVG)

        try unit.sigilSVG.write(
            to: unitDirectory.appendingPathComponent("sigil.svg"),
            atomically: true,
            encoding: .utf8
        )

        try qrSVG.write(
            to: unitDirectory.appendingPathComponent("qr.svg"),
            atomically: true,
            encoding: .utf8
        )

        try frontSVG.write(
            to: unitDirectory.appendingPathComponent("front.svg"),
            atomically: true,
            encoding: .utf8
        )

        try backSVG.write(
            to: unitDirectory.appendingPathComponent("back.svg"),
            atomically: true,
            encoding: .utf8
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let persistedUnit = PersistedUnitOutput(
            unit: unit,
            creationDate: try existingCreationDate(at: dataURL) ?? creationDateFormatter.string(from: Date())
        )
        let data = try encoder.encode(persistedUnit)
        try data.write(to: dataURL)
    }

    func delete(unitID: Int, outputRoot: URL) throws {
        let unitDirectory = outputRoot.appendingPathComponent(String(unitID), isDirectory: true)

        if FileManager.default.fileExists(atPath: unitDirectory.path) {
            try FileManager.default.removeItem(at: unitDirectory)
        }
    }

    func existingUnitIDs(outputRoot: URL) throws -> [Int] {
        guard FileManager.default.fileExists(atPath: outputRoot.path) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: outputRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let unitIDs = urls.compactMap { url -> Int? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }

            return Int(url.lastPathComponent)
        }

        return unitIDs.sorted()
    }

    private func existingCreationDate(at dataURL: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: dataURL)
        let payload = try JSONDecoder().decode(CreationDatePayload.self, from: data)
        return payload.creationDate
    }
}

private struct PersistedUnitOutput: Encodable {
    let unit: UnitOutput
    let creationDate: String

    enum CodingKeys: String, CodingKey {
        case unitID = "unit_id"
        case permutation
        case canonicalDistance = "canonical_distance"
        case events
        case memory
        case hash
        case sigilSVG = "sigil_svg"
        case creationDate = "creation_date"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unit.unitID, forKey: .unitID)
        try container.encode(unit.permutation.values, forKey: .permutation)
        try container.encode(unit.canonicalDistance, forKey: .canonicalDistance)
        try container.encode(unit.events.map(PersistedUnitEvent.init), forKey: .events)
        try container.encode(unit.memory, forKey: .memory)
        try container.encode(unit.hash, forKey: .hash)
        try container.encode(unit.sigilSVG, forKey: .sigilSVG)
        try container.encode(creationDate, forKey: .creationDate)
    }
}

private struct CreationDatePayload: Decodable {
    let creationDate: String?

    enum CodingKeys: String, CodingKey {
        case creationDate = "creation_date"
    }
}

private struct PersistedUnitEvent: Encodable {
    let type: String
    let permutation: [UInt8]?
    let bitmask: UInt8?
    let topology: UInt8?

    init(_ event: FoldEvent) {
        switch event {
        case .permutationCommit(let permutation):
            type = "permutation_commit"
            self.permutation = permutation.values
            bitmask = nil
            topology = nil
        case .lockStateChange(let state):
            type = "lock_state_change"
            permutation = nil
            bitmask = state
            topology = nil
        case .foldTopologyChange(let value):
            type = "fold_topology_change"
            permutation = nil
            bitmask = nil
            topology = value
        }
    }
}
