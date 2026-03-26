import Foundation

struct ArtifactVerifier {
    private let engine: SovereignEngine
    private let outputWriter: OutputWriter

    init(engine: SovereignEngine = SovereignEngine(), outputWriter: OutputWriter = OutputWriter()) {
        self.engine = engine
        self.outputWriter = outputWriter
    }

    func verify(unitID: Int, outputRoot: URL) throws {
        let unitDirectory = outputRoot.appendingPathComponent(String(unitID), isDirectory: true)
        guard FileManager.default.fileExists(atPath: unitDirectory.path) else {
            throw ArtifactVerificationError.missingUnit(unitID)
        }

        let expectedDirectory = try regeneratedArtifacts(for: unitID)
        defer {
            try? FileManager.default.removeItem(at: expectedDirectory.deletingLastPathComponent())
        }

        for filename in Self.requiredFiles {
            let actualURL = unitDirectory.appendingPathComponent(filename)
            let expectedURL = expectedDirectory.appendingPathComponent(filename)

            guard FileManager.default.fileExists(atPath: actualURL.path) else {
                throw ArtifactVerificationError.missingFile(unitID: unitID, filename: filename)
            }

            let actual = try Data(contentsOf: actualURL)
            let expected = try Data(contentsOf: expectedURL)

            guard actual == expected else {
                throw ArtifactVerificationError.mismatch(unitID: unitID, filename: filename)
            }
        }
    }

    private func regeneratedArtifacts(for unitID: Int) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let unit = try engine.generateUnit(unitID: unitID)
        try outputWriter.write(unit: unit, outputRoot: root)
        return root.appendingPathComponent(String(unitID), isDirectory: true)
    }

    private static let requiredFiles = [
        "data.json",
        "sigil.svg",
        "front.svg",
        "back.svg",
        "qr.svg"
    ]
}

enum ArtifactVerificationError: Error, LocalizedError {
    case missingUnit(Int)
    case missingFile(unitID: Int, filename: String)
    case mismatch(unitID: Int, filename: String)

    var errorDescription: String? {
        switch self {
        case .missingUnit(let unitID):
            return "Unit \(unitID) has no generated artifact directory to verify."
        case .missingFile(let unitID, let filename):
            return "Unit \(unitID) is missing required artifact file \(filename)."
        case .mismatch(let unitID, let filename):
            return "Unit \(unitID) failed verification for \(filename)."
        }
    }
}
