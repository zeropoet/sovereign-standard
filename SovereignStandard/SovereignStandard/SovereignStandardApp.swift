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
            let claimFileURL = URL(fileURLWithPath: claimFilePath, relativeTo: rootURL)
            let claimData = try Data(contentsOf: claimFileURL)
            let submission = try JSONDecoder().decode(ClaimSubmission.self, from: claimData)
            try ClaimsStore(root: rootURL).persist(submission: submission, outputRoot: outputRoot)
            shouldSyncSite = true
        case .clearClaim(let unitID):
            try assertUnitExists(unitID: unitID, outputRoot: outputRoot)
            try ClaimsStore(root: rootURL).clear(unitID: unitID)
            shouldSyncSite = true
        case .setPartner(let unitID, let reference):
            try assertUnitExists(unitID: unitID, outputRoot: outputRoot)
            try ClaimsStore(root: rootURL).clear(unitID: unitID)
            try PartnerStore(root: rootURL).setPartner(unitID: unitID, reference: reference)
            shouldSyncSite = true
        case .clearPartner(let unitID):
            try assertUnitExists(unitID: unitID, outputRoot: outputRoot)
            try PartnerStore(root: rootURL).clear(unitID: unitID)
            shouldSyncSite = true
        }

        if shouldSyncSite {
            let unitIDs = try outputWriter.existingUnitIDs(outputRoot: outputRoot)
            let claimsStore = ClaimsStore(root: rootURL)
            try claimsStore.save(try claimsStore.load())
            try siteWriter.write(units: unitIDs, root: rootURL)
            try ClaimCodeManifestWriter(root: rootURL).write(units: unitIDs, outputRoot: outputRoot, root: rootURL)
        }
    }

    private func assertUnitExists(unitID: Int, outputRoot: URL) throws {
        let dataURL = outputRoot
            .appendingPathComponent(String(unitID), isDirectory: true)
            .appendingPathComponent("data.json")

        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            throw SovereignCommandError.invalidUnitID(String(unitID))
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
    case clearClaim(Int)
    case setPartner(Int, String?)
    case clearPartner(Int)

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
        case "clear-claim":
            self = .clearClaim(try Self.singleUnitID(from: Array(payload.dropFirst())))
        case "set-partner":
            let remainder = Array(payload.dropFirst())
            let unitID = try Self.singleUnitID(from: Array(remainder.prefix(1)))
            let reference = remainder.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            self = .setPartner(unitID, reference.isEmpty ? nil : reference)
        case "clear-partner":
            self = .clearPartner(try Self.singleUnitID(from: Array(payload.dropFirst())))
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

    private static func singleUnitID(from rawValues: [String]) throws -> Int {
        let unitIDs = try unitIDs(from: rawValues)
        guard let unitID = unitIDs.first, unitIDs.count == 1 else {
            throw SovereignCommandError.requiresSingleUnitID
        }
        return unitID
    }
}

private enum SovereignCommandError: Error, LocalizedError {
    case invalidCommand(String)
    case invalidUnitID(String)
    case missingUnitIDs
    case missingClaimFile
    case requiresSingleUnitID

    var errorDescription: String? {
        switch self {
        case .invalidCommand(let command):
            return "Unknown command '\(command)'. Use generate, delete, verify, verify-all, sync-site, persist-claim, clear-claim, set-partner, or clear-partner."
        case .invalidUnitID(let value):
            return "Invalid unit id '\(value)'."
        case .missingUnitIDs:
            return "No unit ids were provided."
        case .missingClaimFile:
            return "No claim submission file was provided."
        case .requiresSingleUnitID:
            return "Exactly one unit id must be provided."
        }
    }
}
