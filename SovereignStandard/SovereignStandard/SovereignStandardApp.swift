import Foundation

struct SovereignStandardApp {
    let engine = SovereignEngine()
    let outputWriter = OutputWriter()
    let siteWriter = SiteWriter()

    func run(arguments: [String] = CommandLine.arguments) throws {
        let command = try SovereignCommand(arguments: arguments)
        let outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("output", isDirectory: true)

        switch command {
        case .generate(let unitIDs):
            for unitID in unitIDs {
                let unit = engine.generateUnit(unitID: unitID)
                try outputWriter.write(unit: unit, outputRoot: outputRoot)
            }
        case .delete(let unitIDs):
            for unitID in unitIDs {
                try outputWriter.delete(unitID: unitID, outputRoot: outputRoot)
            }
        case .syncSite:
            break
        }

        let unitIDs = try outputWriter.existingUnitIDs(outputRoot: outputRoot)
        try siteWriter.write(units: unitIDs, root: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    }
}

private enum SovereignCommand {
    case generate([Int])
    case delete([Int])
    case syncSite

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
        case "sync-site":
            self = .syncSite
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

    var errorDescription: String? {
        switch self {
        case .invalidCommand(let command):
            return "Unknown command '\(command)'. Use generate, delete, or sync-site."
        case .invalidUnitID(let value):
            return "Invalid unit id '\(value)'."
        case .missingUnitIDs:
            return "No unit ids were provided."
        }
    }
}
