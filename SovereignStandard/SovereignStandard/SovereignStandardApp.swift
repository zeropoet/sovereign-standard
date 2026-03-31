import Foundation

struct SovereignStandardApp {
    let engine = SovereignEngine()
    let outputWriter = OutputWriter()
    let siteWriter = SiteWriter()
    let artifactVerifier = ArtifactVerifier()

    func run(arguments: [String] = CommandLine.arguments) throws {
        let command = try SovereignCommand(arguments: arguments)
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("output", isDirectory: true)
        let shouldSyncSite: Bool

        switch command {
        case .generate(let unitIDs):
            for unitID in unitIDs {
                let unit = try engine.generateUnit(unitID: unitID)
                try outputWriter.write(unit: unit, outputRoot: outputRoot)
            }
            for unitID in unitIDs {
                try artifactVerifier.verify(unitID: unitID, outputRoot: outputRoot)
                print("verified \(unitID)")
            }
            shouldSyncSite = true
        case .delete(let unitIDs):
            for unitID in unitIDs {
                try outputWriter.delete(unitID: unitID, outputRoot: outputRoot)
            }
            shouldSyncSite = true
        case .verify(let unitIDs):
            for unitID in unitIDs {
                try artifactVerifier.verify(unitID: unitID, outputRoot: outputRoot)
                print("verified \(unitID)")
            }
            shouldSyncSite = false
        case .verifyAll:
            let unitIDs = try outputWriter.existingUnitIDs(outputRoot: outputRoot)
            for unitID in unitIDs {
                try artifactVerifier.verify(unitID: unitID, outputRoot: outputRoot)
                print("verified \(unitID)")
            }
            shouldSyncSite = false
        case .syncSite:
            shouldSyncSite = true
        case .persistClaim(let claimFilePath):
            let claimData = try Data(contentsOf: URL(fileURLWithPath: claimFilePath, relativeTo: rootURL))
            let submission = try JSONDecoder().decode(ClaimSubmission.self, from: claimData)
            try ClaimsStore(root: rootURL).persist(submission: submission, outputRoot: outputRoot)
            shouldSyncSite = true
        }

        if shouldSyncSite {
            let unitIDs = try outputWriter.existingUnitIDs(outputRoot: outputRoot)
            try siteWriter.write(units: unitIDs, root: rootURL)
        }
    }
}

private enum SovereignCommand {
    case generate([Int])
    case delete([Int])
    case verify([Int])
    case verifyAll
    case syncSite
    case persistClaim(String)

    init(arguments: [String]) throws {
        let payload = Array(arguments.dropFirst())

        guard let verb = payload.first else {
            self = .generate(Array(136..<150))
            return
        }

        switch verb {
        case "generate":
            self = .generate(try Self.unitIDs(from: Array(payload.dropFirst())))
        case "delete":
            self = .delete(try Self.unitIDs(from: Array(payload.dropFirst())))
        case "verify":
            self = .verify(try Self.unitIDs(from: Array(payload.dropFirst())))
        case "verify-all":
            self = .verifyAll
        case "sync-site":
            self = .syncSite
        case "persist-claim":
            guard let claimFilePath = payload.dropFirst().first else {
                throw SovereignCommandError.missingClaimFile
            }
            self = .persistClaim(claimFilePath)
        default:
            throw SovereignCommandError.invalidCommand(verb)
        }
    }

    private static func unitIDs(from rawValues: [String]) throws -> [Int] {
        let values = rawValues
            .flatMap { $0.split(separator: ",") }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !values.isEmpty else {
            throw SovereignCommandError.missingUnitIDs
        }

        let unitIDs = try values.map { value -> Int in
            guard let unitID = Int(value) else {
                throw SovereignCommandError.invalidUnitID(value)
            }
            return unitID
        }

        return Array(Set(unitIDs)).sorted()
    }
}

private enum SovereignCommandError: Error, LocalizedError {
    case invalidCommand(String)
    case invalidUnitID(String)
    case missingUnitIDs
    case missingClaimFile

    var errorDescription: String? {
        switch self {
        case .invalidCommand(let command):
            return "Unknown command '\(command)'. Use generate, delete, verify, verify-all, sync-site, or persist-claim."
        case .invalidUnitID(let value):
            return "Invalid unit id '\(value)'."
        case .missingUnitIDs:
            return "No unit ids were provided."
        case .missingClaimFile:
            return "No claim submission file was provided."
        }
    }
}
