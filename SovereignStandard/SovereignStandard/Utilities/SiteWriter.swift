import Foundation

struct SiteWriter {
    func write(units: [Int], root: URL) throws {
        let claims = try ClaimsStore(root: root).load()
        let manifest = try SiteManifest(units: units, claims: claims, root: root)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(manifest)
        try data.write(to: root.appendingPathComponent("units.json"))
    }
}

private struct SiteManifest: Encodable {
    let kernelVersion: String
    let generatedAt: Date
    let units: [UnitRegistryRecord]

    init(units: [Int], claims: [PersistedClaim], root: URL) throws {
        let outputRoot = root.appendingPathComponent("output", isDirectory: true)
        let claimsByUnit = Dictionary(uniqueKeysWithValues: claims.map { ($0.unit, $0) })
        self.units = try units.map { unitID in
            try UnitRegistryRecord(
                unitID: unitID,
                committedClaim: claimsByUnit[unitID],
                outputRoot: outputRoot
            )
        }
        kernelVersion = "1.0.0"
        generatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case kernelVersion = "kernel_version"
        case generatedAt = "generated_at"
        case units
    }
}

private struct UnitRegistryRecord: Encodable {
    let unit: Int
    let timestamp: String
    let state: String
    let product: ProductRecord
    let physical: PhysicalRecord
    let system: SystemRecord
    let claim: ClaimRecord?
    let partner: PartnerRecord?

    enum CodingKeys: String, CodingKey {
        case unit
        case timestamp
        case state
        case product
        case physical
        case system
        case claim
        case partner
    }

    init(unitID: Int, committedClaim: PersistedClaim?, outputRoot: URL) throws {
        let directory = outputRoot.appendingPathComponent(String(unitID), isDirectory: true)
        let dataURL = directory.appendingPathComponent("data.json")
        let issuanceURL = directory.appendingPathComponent("issuance.json")

        let unitData = try JSONDecoder().decode(UnitDataPayload.self, from: Data(contentsOf: dataURL))
        let issuance = try JSONDecoder().decode(ArtifactIssuance.self, from: Data(contentsOf: issuanceURL))
        let issuedAt = Self.timestamp(from: issuance.creationDate)
        let frontMark = String(unitData.hash.prefix(9)).uppercased()

        unit = unitID
        timestamp = issuedAt
        state = committedClaim == nil ? "CLAIMABLE" : "CLAIMED"
        product = ProductRecord(
            blend: "Green Sencha / Lemon Balm / Kapoor Tulsi / Ginger",
            version: "1.0"
        )
        physical = PhysicalRecord(
            tinSerial: frontMark,
            sigil: "output/\(unitID)/sigil.svg"
        )
        system = SystemRecord(
            seed: String(unitID),
            convergenceHash: unitData.hash,
            memoryBytes: Self.memoryFootprint(for: unitData.memory),
            kernelVersion: Self.normalizedKernelVersion(unitData.kernelVersion)
        )
        claim = committedClaim.map(ClaimRecord.init)
        partner = nil
    }

    private static func timestamp(from creationDate: String) -> String {
        if creationDate.contains("T") {
            return creationDate
        }

        return "\(creationDate)T00:00:00Z"
    }

    private static func normalizedKernelVersion(_ kernelVersion: String) -> String {
        if let version = kernelVersion.split(separator: "-").last, version.first?.isNumber == true {
            return String(version)
        }

        return kernelVersion
    }

    // Report a deterministic compressed footprint rather than the fixed buffer allotment.
    private static func memoryFootprint(for memory: [UInt8]) -> Int {
        guard !memory.isEmpty else {
            return 0
        }

        var size = 0
        var index = 0

        while index < memory.count {
            let value = memory[index]
            var runLength = 1

            while index + runLength < memory.count,
                  memory[index + runLength] == value,
                  runLength < 255 {
                runLength += 1
            }

            size += 2
            index += runLength
        }

        return size
    }
}

private struct ProductRecord: Encodable {
    let blend: String
    let version: String

    enum CodingKeys: String, CodingKey {
        case blend
        case version
    }
}

private struct PhysicalRecord: Encodable {
    let tinSerial: String
    let sigil: String

    enum CodingKeys: String, CodingKey {
        case tinSerial = "tin_serial"
        case sigil
    }
}

private struct SystemRecord: Encodable {
    let seed: String
    let convergenceHash: String
    let memoryBytes: Int
    let kernelVersion: String

    enum CodingKeys: String, CodingKey {
        case seed
        case convergenceHash = "convergence_hash"
        case memoryBytes = "memory_bytes"
        case kernelVersion = "kernel_version"
    }
}

private struct ClaimRecord: Encodable {
    let name: String?
    let signal: String?
    let claimedAt: String
    let claimHash: String
    let verification: VerificationRecord

    enum CodingKeys: String, CodingKey {
        case name
        case signal
        case claimedAt = "claimed_at"
        case claimHash = "claim_hash"
        case verification
    }

    init(_ claim: PersistedClaim) {
        name = claim.name
        signal = claim.publicSignal
        claimedAt = claim.claimedAt
        claimHash = claim.claimHash
        verification = VerificationRecord(
            method: claim.verification.method,
            confidence: claim.verification.confidence
        )
    }
}

private struct VerificationRecord: Encodable {
    let method: String
    let confidence: Double
}

private struct PartnerRecord: Encodable {
    let activatedAt: String
    let type: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case activatedAt = "activated_at"
        case type
        case notes
    }
}

private struct UnitDataPayload: Decodable {
    let hash: String
    let memory: [UInt8]
    let kernelVersion: String

    enum CodingKeys: String, CodingKey {
        case hash
        case memory
        case kernelVersion = "kernel_version"
    }
}
