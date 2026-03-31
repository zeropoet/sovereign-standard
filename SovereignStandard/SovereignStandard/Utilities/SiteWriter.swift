import Foundation

struct SiteWriter {
    func write(units: [Int], root: URL) throws {
        let claims = try ClaimsStore(root: root).load()
        let authority = try ClaimCodeAuthority(root: root)
        let partners = try PartnerStore(root: root).load()
        let manifest = try SiteManifest(units: units, claims: claims, partners: partners, authority: authority, root: root)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(manifest)
        try data.write(to: root.appendingPathComponent("units.json"))
    }
}

private struct SiteManifest: Encodable {
    let generatedAt: Date
    let units: [UnitRegistryRecord]

    init(units: [Int], claims: [PersistedClaim], partners: [Int: PartnerAssignment], authority: ClaimCodeAuthority, root: URL) throws {
        let outputRoot = root.appendingPathComponent("output", isDirectory: true)
        let claimsByUnit = Dictionary(uniqueKeysWithValues: claims.map { ($0.unit, $0) })
        self.units = try units.map { unitID in
            try UnitRegistryRecord(
                unitID: unitID,
                committedClaim: claimsByUnit[unitID],
                partnerAssignment: partners[unitID],
                authority: authority,
                outputRoot: outputRoot
            )
        }
        generatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case units
    }
}

private struct UnitRegistryRecord: Encodable {
    let id: Int
    let state: String
    let claimHash: String?
    let claimedAt: String?
    let holderHash: String?
    let isPartner: Bool
    let sigil: String?
    let createdAt: String
    let partnerReference: String?

    enum CodingKeys: String, CodingKey {
        case id
        case state
        case claimHash = "claim_hash"
        case claimedAt = "claimed_at"
        case holderHash = "holder_hash"
        case isPartner = "is_partner"
        case sigil
        case createdAt = "created_at"
        case partnerReference = "partner_reference"
    }

    init(
        unitID: Int,
        committedClaim: PersistedClaim?,
        partnerAssignment: PartnerAssignment?,
        authority: ClaimCodeAuthority,
        outputRoot: URL
    ) throws {
        let directory = outputRoot.appendingPathComponent(String(unitID), isDirectory: true)
        let dataURL = directory.appendingPathComponent("data.json")
        let issuanceURL = directory.appendingPathComponent("issuance.json")

        let unitData = try JSONDecoder().decode(UnitDataPayload.self, from: Data(contentsOf: dataURL))
        let issuance = try JSONDecoder().decode(ArtifactIssuance.self, from: Data(contentsOf: issuanceURL))
        let claimCode = authority.claimCode(for: unitData.hash)
        let publicClaimHash = ClaimCodeAuthority.claimHash(for: claimCode)
        let assignedState = partnerAssignment?.state ?? (committedClaim == nil ? "CLAIMABLE" : "CLAIMED")

        id = unitID
        state = assignedState
        isPartner = assignedState == "PARTNER"
        sigil = assignedState == "CLAIMABLE" ? nil : "output/\(unitID)/sigil.svg"
        createdAt = Self.timestamp(from: issuance.creationDate)
        partnerReference = partnerAssignment?.reference?.nilIfBlank

        switch assignedState {
        case "PARTNER":
            claimHash = nil
            claimedAt = nil
            holderHash = nil
        case "CLAIMED":
            claimHash = publicClaimHash
            claimedAt = committedClaim?.claimedAt
            holderHash = committedClaim?.resolvedHolderHash
        default:
            claimHash = publicClaimHash
            claimedAt = nil
            holderHash = nil
        }
    }

    private static func timestamp(from creationDate: String) -> String {
        if creationDate.contains("T") {
            return creationDate
        }

        return "\(creationDate)T00:00:00Z"
    }
}

private struct UnitDataPayload: Decodable {
    let hash: String
}

private extension PersistedClaim {
    var resolvedHolderHash: String {
        holderHash
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
