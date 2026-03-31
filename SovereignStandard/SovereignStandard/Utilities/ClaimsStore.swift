import Foundation
import FoldKernel

struct ClaimsStore {
    private let claimsURL: URL
    private let proofVerifier = ClaimProofVerifier()

    init(root: URL) {
        claimsURL = root.appendingPathComponent("claims.json")
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

    func persist(submission: ClaimSubmission, outputRoot: URL, claimFileURL: URL? = nil) throws {
        let unitDirectory = outputRoot.appendingPathComponent(String(submission.unit), isDirectory: true)
        let dataURL = unitDirectory.appendingPathComponent("data.json")

        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            throw ClaimPersistenceError.unitNotFound(submission.unit)
        }

        let unitData = try JSONDecoder().decode(ClaimUnitDataPayload.self, from: Data(contentsOf: dataURL))
        switch submission.verification.method.lowercased() {
        case "hash":
            let expectedFrontMark = Self.frontMark(for: unitData.hash)
            guard Self.normalizeFrontMark(submission.frontMark ?? "") == expectedFrontMark else {
                throw ClaimPersistenceError.frontMarkMismatch
            }

            let expectedClaimHash = Self.claimHash(
                convergenceHash: unitData.hash,
                frontMark: expectedFrontMark,
                email: submission.email,
                claimedAt: submission.claimedAt
            )
            guard submission.claimHash == expectedClaimHash else {
                throw ClaimPersistenceError.claimHashMismatch
            }
        case "image", "hybrid":
            guard let imageSHA256 = submission.imageSHA256?.nilIfBlank else {
                throw ClaimPersistenceError.missingImageHash
            }
            guard let proofImagePath = submission.proofImagePath?.nilIfBlank else {
                throw ClaimPersistenceError.missingProofImage
            }

            let baseURL = claimFileURL?.deletingLastPathComponent() ?? claimsURL.deletingLastPathComponent()
            let proofImageURL = URL(fileURLWithPath: proofImagePath, relativeTo: baseURL)
            let expectedUnitURL = SiteConfiguration.unitURL(for: submission.unit)

            try proofVerifier.verify(
                imageAt: proofImageURL,
                expectedSHA256: imageSHA256,
                expectedUnitURL: expectedUnitURL
            )

            let expectedClaimHash = Self.claimHash(
                convergenceHash: unitData.hash,
                unitURL: expectedUnitURL,
                imageSHA256: imageSHA256,
                email: submission.email,
                claimedAt: submission.claimedAt
            )
            guard submission.claimHash == expectedClaimHash else {
                throw ClaimPersistenceError.claimHashMismatch
            }
        default:
            throw ClaimPersistenceError.unsupportedVerificationMethod
        }

        var claims = try load()
        guard !claims.contains(where: { $0.unit == submission.unit }) else {
            throw ClaimPersistenceError.alreadyClaimed(submission.unit)
        }

        claims.append(
            PersistedClaim(
                unit: submission.unit,
                emailHash: Self.emailHash(for: submission.email),
                name: submission.name?.nilIfBlank,
                publicSignal: Self.publicSignal(name: submission.name, email: submission.email),
                claimedAt: submission.claimedAt,
                claimHash: submission.claimHash,
                verification: submission.verification
            )
        )

        try save(claims)
    }

    static func emailHash(for email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return hex(Keccak256().hash(Array(normalized.utf8)))
    }

    static func publicSignal(name: String?, email: String) -> String? {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? "collector"
        let trimmed = localPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let first = trimmed.prefix(1).uppercased()
        let second = trimmed.dropFirst().prefix(1)
        return "\(first)\(second)\u{2026}"
    }

    static func frontMark(for convergenceHash: String) -> String {
        String(convergenceHash.prefix(9)).uppercased()
    }

    static func claimHash(
        convergenceHash: String,
        frontMark: String,
        email: String,
        claimedAt: String
    ) -> String {
        let payload = convergenceHash
            + normalizeFrontMark(frontMark)
            + email
            + claimedAt

        return hex(Keccak256().hash(Array(payload.utf8)))
    }

    static func claimHash(
        convergenceHash: String,
        unitURL: String,
        imageSHA256: String,
        email: String,
        claimedAt: String
    ) -> String {
        let payload = convergenceHash
            + unitURL
            + imageSHA256.lowercased()
            + email
            + claimedAt

        return hex(Keccak256().hash(Array(payload.utf8)))
    }

    static func normalizeFrontMark(_ value: String) -> String {
        String(
            value
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
        )
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

struct ClaimSubmission: Codable {
    let unit: Int
    let email: String
    let name: String?
    let claimedAt: String
    let claimHash: String
    let frontMark: String?
    let imageSHA256: String?
    let proofImagePath: String?
    let verification: PersistedClaimVerification

    enum CodingKeys: String, CodingKey {
        case unit
        case email
        case name
        case claimedAt = "claimed_at"
        case claimHash = "claim_hash"
        case frontMark = "front_mark"
        case imageSHA256 = "image_sha256"
        case proofImagePath = "proof_image_path"
        case verification
    }
}

struct PersistedClaim: Codable {
    let unit: Int
    let emailHash: String
    let name: String?
    let publicSignal: String?
    let claimedAt: String
    let claimHash: String
    let verification: PersistedClaimVerification

    enum CodingKeys: String, CodingKey {
        case unit
        case emailHash = "email_hash"
        case name
        case publicSignal = "public_signal"
        case claimedAt = "claimed_at"
        case claimHash = "claim_hash"
        case verification
    }
}

struct PersistedClaimVerification: Codable {
    let method: String
    let confidence: Double
}

private struct PersistedClaimsManifest: Codable {
    let claims: [PersistedClaim]
}

private struct ClaimUnitDataPayload: Decodable {
    let hash: String
}

private enum ClaimPersistenceError: Error, LocalizedError {
    case alreadyClaimed(Int)
    case claimHashMismatch
    case frontMarkMismatch
    case missingImageHash
    case missingProofImage
    case unitNotFound(Int)
    case unsupportedVerificationMethod

    var errorDescription: String? {
        switch self {
        case .alreadyClaimed(let unit):
            return "Unit \(unit) already has a committed claim."
        case .claimHashMismatch:
            return "Claim hash verification failed."
        case .frontMarkMismatch:
            return "Front mark verification failed."
        case .missingImageHash:
            return "Proof image hash was not provided."
        case .missingProofImage:
            return "Proof image was not provided."
        case .unitNotFound(let unit):
            return "Unit \(unit) does not exist in output."
        case .unsupportedVerificationMethod:
            return "Verification method is not supported."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
