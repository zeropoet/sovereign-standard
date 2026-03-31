import Foundation
import FoldKernel

struct ClaimCodeAuthority {
    static let environmentKey = "SOVEREIGN_CLAIM_SECRET"
    static let secretRelativePath = ".secrets/claim-master.txt"

    private static let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    private let masterSecret: String

    init(root: URL, masterSecret: String? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        if let masterSecret, !masterSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.masterSecret = masterSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            return
        }

        if let envSecret = environment[Self.environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envSecret.isEmpty {
            self.masterSecret = envSecret
            return
        }

        let secretURL = root.appendingPathComponent(Self.secretRelativePath)
        if let fileSecret = try? String(contentsOf: secretURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fileSecret.isEmpty {
            self.masterSecret = fileSecret
            return
        }

        throw ClaimCodeAuthorityError.missingSecret
    }

    func claimCode(for convergenceHash: String) -> String {
        let payload = "\(masterSecret)\(convergenceHash):claim-code:v1"
        let bytes = Keccak256().hash(Array(payload.utf8))
        let encoded = Self.base32(Array(bytes.prefix(10)))
        return Self.formatCode(encoded)
    }

    func verify(claimCode submittedCode: String, convergenceHash: String) -> Bool {
        Self.normalizeClaimCode(submittedCode) == Self.normalizeClaimCode(claimCode(for: convergenceHash))
    }

    static func claimHash(
        for claimCode: String
    ) -> String {
        let payload = normalizeClaimCode(claimCode)
        return hex(Keccak256().hash(Array(payload.utf8)))
    }

    static func holderHash(
        claimCode: String,
        claimedAt: String,
        unitID: Int
    ) -> String {
        let payload = normalizeClaimCode(claimCode)
            + claimedAt
            + String(unitID)

        return hex(Keccak256().hash(Array(payload.utf8)))
    }

    static func normalizeClaimCode(_ value: String) -> String {
        String(
            value
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
        )
    }

    private static func formatCode(_ value: String) -> String {
        stride(from: 0, to: value.count, by: 4).map { offset in
            let start = value.index(value.startIndex, offsetBy: offset)
            let end = value.index(start, offsetBy: min(4, value.distance(from: start, to: value.endIndex)))
            return String(value[start..<end])
        }
        .joined(separator: "-")
    }

    private static func base32(_ bytes: [UInt8]) -> String {
        var output = ""
        var buffer = 0
        var bitsRemaining = 0

        for byte in bytes {
            buffer = (buffer << 8) | Int(byte)
            bitsRemaining += 8

            while bitsRemaining >= 5 {
                let index = (buffer >> (bitsRemaining - 5)) & 0x1f
                output.append(alphabet[index])
                bitsRemaining -= 5
            }
        }

        if bitsRemaining > 0 {
            let index = (buffer << (5 - bitsRemaining)) & 0x1f
            output.append(alphabet[index])
        }

        return output
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

struct ClaimCodeManifestWriter {
    private let authority: ClaimCodeAuthority

    init(root: URL, masterSecret: String? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        authority = try ClaimCodeAuthority(root: root, masterSecret: masterSecret, environment: environment)
    }

    func write(units: [Int], outputRoot: URL, root: URL) throws {
        let privateRoot = root.appendingPathComponent("private", isDirectory: true)
        try FileManager.default.createDirectory(at: privateRoot, withIntermediateDirectories: true)

        let entries = try units.map { unitID -> ClaimCodeManifestEntry in
            let dataURL = outputRoot
                .appendingPathComponent(String(unitID), isDirectory: true)
                .appendingPathComponent("data.json")
            let unitData = try JSONDecoder().decode(ClaimCodeUnitDataPayload.self, from: Data(contentsOf: dataURL))
            return ClaimCodeManifestEntry(
                unit: unitID,
                claimCode: authority.claimCode(for: unitData.hash),
                unitURL: SiteConfiguration.unitURL(for: unitID),
                convergenceHashPrefix: String(unitData.hash.prefix(12))
            )
        }

        let manifest = ClaimCodeManifest(generatedAt: Self.timestampFormatter.string(from: Date()), units: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: privateRoot.appendingPathComponent("claim-codes.json"))
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct ClaimCodeManifest: Codable {
    let generatedAt: String
    let units: [ClaimCodeManifestEntry]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case units
    }
}

private struct ClaimCodeManifestEntry: Codable {
    let unit: Int
    let claimCode: String
    let unitURL: String
    let convergenceHashPrefix: String

    enum CodingKeys: String, CodingKey {
        case unit
        case claimCode = "claim_code"
        case unitURL = "unit_url"
        case convergenceHashPrefix = "convergence_hash_prefix"
    }
}

private struct ClaimCodeUnitDataPayload: Decodable {
    let hash: String
}

enum ClaimCodeAuthorityError: LocalizedError {
    case missingSecret

    var errorDescription: String? {
        switch self {
        case .missingSecret:
            return "Missing claim-code master secret. Set SOVEREIGN_CLAIM_SECRET or create .secrets/claim-master.txt."
        }
    }
}
