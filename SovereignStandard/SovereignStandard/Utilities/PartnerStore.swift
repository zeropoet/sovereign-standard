import Foundation

struct PartnerStore {
    private let partnersURL: URL

    init(root: URL) {
        partnersURL = root.appendingPathComponent("partners.json")
    }

    func load() throws -> [Int: PartnerAssignment] {
        guard FileManager.default.fileExists(atPath: partnersURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: partnersURL)
        let manifest = try JSONDecoder().decode(PartnerManifest.self, from: data)
        return Dictionary(uniqueKeysWithValues: manifest.units.map { ($0.id, $0) })
    }

    func save(_ assignments: [Int: PartnerAssignment]) throws {
        let manifest = PartnerManifest(
            units: assignments.values.sorted { lhs, rhs in
                lhs.id < rhs.id
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: partnersURL)
    }

    func setPartner(unitID: Int, reference: String?) throws {
        var assignments = try load()
        assignments[unitID] = PartnerAssignment(
            id: unitID,
            state: "PARTNER",
            reference: reference?.nilIfBlank
        )
        try save(assignments)
    }

    func clear(unitID: Int) throws {
        var assignments = try load()
        assignments.removeValue(forKey: unitID)
        try save(assignments)
    }
}

struct PartnerManifest: Codable {
    let units: [PartnerAssignment]
}

struct PartnerAssignment: Codable {
    let id: Int
    let state: String
    let reference: String?
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
