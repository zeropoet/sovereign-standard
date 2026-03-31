import Foundation
import FoldKernel

struct ClaimsStore {
    private let claimsURL: URL

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

    func persist(submission: ClaimSubmission, outputRoot: URL) throws {
        let unitDirectory = outputRoot.appendingPathComponent(String(submission.unit), isDirectory: true)
        let dataURL = unitDirectory.appendingPathComponent("data.json")

        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            throw ClaimPersistenceError.unitNotFound(submission.unit)
        }

        let unitData = try JSONDecoder().decode(ClaimUnitDataPayload.self, from: Data(contentsOf: dataURL))
        let expectedTinSerial = String(format: "SS-%04d", submission.unit)
        guard submission.tinSerial.caseInsensitiveCompare(expectedTinSerial) == .orderedSame else {
            throw ClaimPersistenceError.tinSerialMismatch
        }

        let expectedProofPhrase = Self.proofPhrase(
            tinSerial: expectedTinSerial,
            engravingHash: unitData.hash
        )
        guard Self.normalizeProofPhrase(submission.proofPhrase) == expectedProofPhrase else {
            throw ClaimPersistenceError.proofPhraseMismatch
        }

        let expectedClaimHash = Self.claimHash(
            convergenceHash: unitData.hash,
            tinSerial: expectedTinSerial,
            proofPhrase: expectedProofPhrase,
            email: submission.email,
            claimedAt: submission.claimedAt
        )
        guard submission.claimHash == expectedClaimHash else {
            throw ClaimPersistenceError.claimHashMismatch
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

    static func proofPhrase(tinSerial: String, engravingHash: String) -> String {
        let serialSuffix = normalizeProofPhrase(tinSerial).suffix(4)
        let engravingSuffix = normalizeProofPhrase(engravingHash).suffix(8)
        return String(serialSuffix + engravingSuffix)
    }

    static func claimHash(
        convergenceHash: String,
        tinSerial: String,
        proofPhrase: String,
        email: String,
        claimedAt: String
    ) -> String {
        let payload = convergenceHash
            + tinSerial.uppercased()
            + normalizeProofPhrase(proofPhrase)
            + email
            + claimedAt

        return hex(Keccak256().hash(Array(payload.utf8)))
    }

    static func normalizeProofPhrase(_ value: String) -> String {
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

struct ClaimSubmission: Decodable {
    let unit: Int
    let email: String
    let name: String?
    let claimedAt: String
    let claimHash: String
    let tinSerial: String
    let proofPhrase: String
    let verification: PersistedClaimVerification

    enum CodingKeys: String, CodingKey {
        case unit
        case email
        case name
        case claimedAt = "claimed_at"
        case claimHash = "claim_hash"
        case tinSerial = "tin_serial"
        case proofPhrase = "proof_phrase"
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
    case proofPhraseMismatch
    case tinSerialMismatch
    case unitNotFound(Int)

    var errorDescription: String? {
        switch self {
        case .alreadyClaimed(let unit):
            return "Unit \(unit) already has a committed claim."
        case .claimHashMismatch:
            return "Claim hash verification failed."
        case .proofPhraseMismatch:
            return "Proof phrase verification failed."
        case .tinSerialMismatch:
            return "Tin serial verification failed."
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
