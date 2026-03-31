import Foundation
struct ClaimsStore {
    private let claimsURL: URL
    private let authority: ClaimCodeAuthority?

    init(root: URL, masterSecret: String? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) {
        claimsURL = root.appendingPathComponent("claims.json")
        authority = try? ClaimCodeAuthority(root: root, masterSecret: masterSecret, environment: environment)
    }

    func load() throws -> [PersistedClaim] {
        guard FileManager.default.fileExists(atPath: claimsURL.path) else {
            return []
        }

        let data = try Data(contentsOf: claimsURL)
        return try JSONDecoder().decode(PersistedClaimsManifest.self, from: data).claims
    }

    func save(_ claims: [PersistedClaim]) throws {
        let manifest = PersistedClaimsManifest(
            claims: claims.sorted { lhs, rhs in
                lhs.unit < rhs.unit
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: claimsURL)
    }

    func persist(submission: ClaimSubmission, outputRoot: URL) throws {
        let unitDirectory = outputRoot.appendingPathComponent(String(submission.unit), isDirectory: true)
        let dataURL = unitDirectory.appendingPathComponent("data.json")

        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            throw ClaimPersistenceError.unitNotFound(submission.unit)
        }

        let unitData = try JSONDecoder().decode(ClaimUnitDataPayload.self, from: Data(contentsOf: dataURL))

        guard let claimCode = submission.claimCode?.nilIfBlank else {
            throw ClaimPersistenceError.missingClaimCode
        }

        guard let authority else {
            throw ClaimPersistenceError.missingClaimSecret
        }

        guard authority.verify(claimCode: claimCode, convergenceHash: unitData.hash) else {
            throw ClaimPersistenceError.claimCodeMismatch
        }

        var claims = try load()
        guard !claims.contains(where: { $0.unit == submission.unit }) else {
            throw ClaimPersistenceError.alreadyClaimed(submission.unit)
        }

        let claimHash = ClaimCodeAuthority.claimHash(for: claimCode)
        let holderHash = ClaimCodeAuthority.holderHash(
            claimCode: claimCode,
            claimedAt: submission.claimedAt,
            unitID: submission.unit
        )

        claims.append(
            PersistedClaim(
                unit: submission.unit,
                claimedAt: submission.claimedAt,
                claimHash: claimHash,
                holderHash: holderHash
            )
        )

        try save(claims)
    }

    func clear(unitID: Int) throws {
        let claims = try load().filter { $0.unit != unitID }
        try save(claims)
    }
}

struct ClaimSubmission: Codable {
    let unit: Int
    let claimedAt: String
    let claimCode: String?

    enum CodingKeys: String, CodingKey {
        case unit
        case claimedAt = "claimed_at"
        case claimCode = "claim_code"
    }
}

struct PersistedClaim: Codable {
    let unit: Int
    let claimedAt: String
    let claimHash: String
    let holderHash: String

    enum CodingKeys: String, CodingKey {
        case unit
        case claimedAt = "claimed_at"
        case claimHash = "claim_hash"
        case holderHash = "holder_hash"
    }

    init(unit: Int, claimedAt: String, claimHash: String, holderHash: String) {
        self.unit = unit
        self.claimedAt = claimedAt
        self.claimHash = claimHash
        self.holderHash = holderHash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let unit = try container.decode(Int.self, forKey: .unit)
        let claimedAt = try container.decode(String.self, forKey: .claimedAt)
        let claimHash = try container.decode(String.self, forKey: .claimHash)
        let holderHash = try container.decodeIfPresent(String.self, forKey: .holderHash)
            ?? Self.legacyHolderHash(claimHash: claimHash, claimedAt: claimedAt, unitID: unit)

        self.init(unit: unit, claimedAt: claimedAt, claimHash: claimHash, holderHash: holderHash)
    }

    private static func legacyHolderHash(claimHash: String, claimedAt: String, unitID: Int) -> String {
        ClaimCodeAuthority.claimHash(for: "\(claimHash)\(claimedAt)\(unitID)")
    }
}

private struct PersistedClaimsManifest: Codable {
    let claims: [PersistedClaim]
}

private struct ClaimUnitDataPayload: Decodable {
    let hash: String
}

private enum ClaimPersistenceError: Error, LocalizedError {
    case alreadyClaimed(Int)
    case claimCodeMismatch
    case missingClaimCode
    case missingClaimSecret
    case unitNotFound(Int)

    var errorDescription: String? {
        switch self {
        case .alreadyClaimed(let unit):
            return "Unit \(unit) already has a committed claim."
        case .claimCodeMismatch:
            return "Internal claim code verification failed."
        case .missingClaimCode:
            return "Internal claim code was not provided."
        case .missingClaimSecret:
            return "Missing claim-code master secret."
        case .unitNotFound(let unit):
            return "Unit \(unit) does not exist in output."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
