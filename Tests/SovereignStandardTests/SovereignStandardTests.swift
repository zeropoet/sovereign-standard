import XCTest
import Foundation
import FoldKernel
@testable import SovereignStandard

final class SovereignStandardTests: XCTestCase {
    private let testClaimSecret = "test-claim-secret"

    func testGenerateUnitIsDeterministic() throws {
        let engine = SovereignEngine()

        let first = try engine.generateUnit(unitID: 136)
        let second = try engine.generateUnit(unitID: 136)

        XCTAssertEqual(first.permutation.values, second.permutation.values)
        XCTAssertEqual(first.memory, second.memory)
        XCTAssertEqual(first.hash, second.hash)
        XCTAssertEqual(first.sigilSVG, second.sigilSVG)
        XCTAssertEqual(first.events.count, second.events.count)
    }

    func testGenerateUnitUsesFixedSpecVersionsAndStepCount() throws {
        let engine = SovereignEngine()

        let unit = try engine.generateUnit(unitID: 136)
        let eventPermutations = permutations(from: unit.events)

        XCTAssertEqual(unit.walkerVersion, SovereignWalker.version)
        XCTAssertEqual(unit.kernelVersion, SovereignEngine.kernelVersion)
        XCTAssertEqual(unit.stepCount, SovereignWalker.stepCount)
        XCTAssertNotEqual(unit.permutation.values, CanonicalSquare.S0.values)
        XCTAssertGreaterThan(unit.canonicalDistance, 0)
        XCTAssertEqual(unit.events.count, SovereignWalker.stepCount)
        XCTAssertEqual(unit.memory.count, SovereignWalker.stepCount * 17)
        XCTAssertEqual(eventPermutations.last, CanonicalSquare.S0.values)
    }

    func testGenerateUnitRejectsNegativeUnitIDs() {
        let engine = SovereignEngine()

        XCTAssertThrowsError(try engine.generateUnit(unitID: -1))
    }

    func testDifferentUnitsProduceDifferentCommitments() throws {
        let engine = SovereignEngine()

        let first = try engine.generateUnit(unitID: 136)
        let second = try engine.generateUnit(unitID: 137)

        XCTAssertNotEqual(first.memory, second.memory)
        XCTAssertNotEqual(first.hash, second.hash)
    }

    func testGoldenVectorsStayStable() throws {
        let engine = SovereignEngine()

        for vector in goldenVectors {
            let unit = try engine.generateUnit(unitID: vector.unitID)
            let eventPermutations = permutations(from: unit.events)

            XCTAssertEqual(unit.hash, vector.hash, "Hash drifted for unit \(vector.unitID)")
            XCTAssertEqual(unit.permutation.values, vector.initialPermutation)
            XCTAssertEqual(unit.events.count, SovereignWalker.stepCount)
            XCTAssertEqual(eventPermutations.first, vector.firstEventPermutation)
            XCTAssertEqual(eventPermutations.last, vector.lastEventPermutation)
        }
    }

    func testOutputWriterProducesBitIdenticalArtifactsAcrossFreshRegeneration() throws {
        let engine = SovereignEngine()
        let writer = OutputWriter()
        let outputRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputRoot)
        }

        let unit = try engine.generateUnit(unitID: 42)

        try writer.write(unit: unit, outputRoot: outputRoot)
        let firstArtifacts = try artifactPayloads(for: unit.unitID, outputRoot: outputRoot)

        try writer.delete(unitID: unit.unitID, outputRoot: outputRoot)
        try writer.write(unit: unit, outputRoot: outputRoot)
        let secondArtifacts = try artifactPayloads(for: unit.unitID, outputRoot: outputRoot)

        XCTAssertEqual(firstArtifacts, secondArtifacts)
    }

    func testOutputWriterRefreshesIssuanceAcrossRewrite() throws {
        let engine = SovereignEngine()
        let writer = OutputWriter()
        let outputRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputRoot)
        }

        let unit = try engine.generateUnit(unitID: 42)

        try writer.write(unit: unit, outputRoot: outputRoot)
        let firstIssuance = try issuancePayload(for: unit.unitID, outputRoot: outputRoot)

        Thread.sleep(forTimeInterval: 1.1)
        try writer.write(unit: unit, outputRoot: outputRoot)
        let secondIssuance = try issuancePayload(for: unit.unitID, outputRoot: outputRoot)

        XCTAssertNotEqual(firstIssuance, secondIssuance)
    }

    func testOutputWriterOverwritesStaleIssuanceOnRewrite() throws {
        let engine = SovereignEngine()
        let writer = OutputWriter()
        let outputRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputRoot)
        }

        let unit = try engine.generateUnit(unitID: 42)
        let unitDirectory = outputRoot.appendingPathComponent(String(unit.unitID), isDirectory: true)
        try FileManager.default.createDirectory(at: unitDirectory, withIntermediateDirectories: true)

        let staleIssuance = ArtifactIssuance(
            creationDate: "2000-01-01",
            integrity: "1.000"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let issuanceData = try encoder.encode(staleIssuance)
        try issuanceData.write(to: unitDirectory.appendingPathComponent("issuance.json"))

        try writer.write(unit: unit, outputRoot: outputRoot)
        let rewrittenIssuance = try issuancePayload(for: unit.unitID, outputRoot: outputRoot)

        XCTAssertNotEqual(rewrittenIssuance.creationDate, "2000-01-01")
        XCTAssertEqual(rewrittenIssuance.integrity, "1.000")
    }

    func testArtifactVerifierAcceptsMatchingArtifacts() throws {
        let engine = SovereignEngine()
        let writer = OutputWriter()
        let verifier = ArtifactVerifier(engine: engine, outputWriter: writer)
        let outputRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputRoot)
        }

        let unit = try engine.generateUnit(unitID: 42)
        try writer.write(unit: unit, outputRoot: outputRoot)

        XCTAssertNoThrow(try verifier.verify(unitID: 42, outputRoot: outputRoot))
    }

    func testArtifactVerifierRejectsTamperedArtifacts() throws {
        let engine = SovereignEngine()
        let writer = OutputWriter()
        let verifier = ArtifactVerifier(engine: engine, outputWriter: writer)
        let outputRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: outputRoot)
        }

        let unit = try engine.generateUnit(unitID: 42)
        try writer.write(unit: unit, outputRoot: outputRoot)

        let dataURL = outputRoot
            .appendingPathComponent("42", isDirectory: true)
            .appendingPathComponent("data.json")
        try Data("tampered".utf8).write(to: dataURL)

        XCTAssertThrowsError(try verifier.verify(unitID: 42, outputRoot: outputRoot))
    }

    func testPersistClaimWritesClaimLedgerAndPublicRegistryState() throws {
        let engine = SovereignEngine()
        let writer = OutputWriter()
        let siteWriter = SiteWriter()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputRoot = root.appendingPathComponent("output", isDirectory: true)

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let unit = try engine.generateUnit(unitID: 42)
        try writer.write(unit: unit, outputRoot: outputRoot)

        let claimsStore = ClaimsStore(root: root, masterSecret: testClaimSecret)
        let claimedAt = "2026-03-31T03:00:00Z"
        let authority = try ClaimCodeAuthority(root: root, masterSecret: testClaimSecret)
        let claimCode = authority.claimCode(for: unit.hash)
        let claimHash = ClaimCodeAuthority.claimHash(
            convergenceHash: unit.hash,
            claimCode: claimCode,
            email: "collector@example.com",
            claimedAt: claimedAt
        )
        let submission = ClaimSubmission(
            unit: 42,
            email: "collector@example.com",
            name: "Collector",
            claimedAt: claimedAt,
            claimHash: claimHash,
            claimCode: claimCode,
            verification: PersistedClaimVerification(method: "code", confidence: 1.0)
        )

        try claimsStore.persist(submission: submission, outputRoot: outputRoot)
        try siteWriter.write(units: [42], root: root)

        let claims = try claimsStore.load()
        XCTAssertEqual(claims.count, 1)
        XCTAssertEqual(claims.first?.unit, 42)
        XCTAssertEqual(claims.first?.name, "Collector")
        XCTAssertNotNil(claims.first?.emailHash)

        let unitsData = try Data(contentsOf: root.appendingPathComponent("units.json"))
        let manifest = try JSONSerialization.jsonObject(with: unitsData) as? [String: Any]
        let units = manifest?["units"] as? [[String: Any]]
        let record = try XCTUnwrap(units?.first)
        let claim = try XCTUnwrap(record["claim"] as? [String: Any])

        XCTAssertEqual(record["state"] as? String, "CLAIMED")
        XCTAssertEqual(claim["claim_hash"] as? String, claimHash)
        XCTAssertEqual(claim["signal"] as? String, "Collector")
        XCTAssertNil(claim["email"])
    }

    func testClaimCodeManifestWriterIsDeterministicAcrossRegeneration() throws {
        let engine = SovereignEngine()
        let writer = OutputWriter()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputRoot = root.appendingPathComponent("output", isDirectory: true)

        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let unit = try engine.generateUnit(unitID: 43)
        try writer.write(unit: unit, outputRoot: outputRoot)
        let manifestWriter = try ClaimCodeManifestWriter(root: root, masterSecret: testClaimSecret)
        try manifestWriter.write(units: [43], outputRoot: outputRoot, root: root)
        let first = try claimCodeManifestData(at: root.appendingPathComponent("private/claim-codes.json"))

        try writer.write(unit: unit, outputRoot: outputRoot)
        try manifestWriter.write(units: [43], outputRoot: outputRoot, root: root)
        let second = try claimCodeManifestData(at: root.appendingPathComponent("private/claim-codes.json"))

        XCTAssertEqual(first, second)
    }

    private func permutations(from events: [FoldEvent]) -> [[UInt8]] {
        events.compactMap { event in
            guard case .permutationCommit(let permutation) = event else {
                return nil
            }

            return permutation.values
        }
    }

    private func artifactPayloads(for unitID: Int, outputRoot: URL) throws -> [String: Data] {
        let unitDirectory = outputRoot.appendingPathComponent(String(unitID), isDirectory: true)
        let filenames = ["data.json", "sigil.svg", "front.svg", "back.svg", "qr.svg"]

        return try filenames.reduce(into: [:]) { result, filename in
            result[filename] = try Data(contentsOf: unitDirectory.appendingPathComponent(filename))
        }
    }

    private func issuancePayload(for unitID: Int, outputRoot: URL) throws -> ArtifactIssuance {
        let unitDirectory = outputRoot.appendingPathComponent(String(unitID), isDirectory: true)
        let data = try Data(contentsOf: unitDirectory.appendingPathComponent("issuance.json"))
        return try JSONDecoder().decode(ArtifactIssuance.self, from: data)
    }

    private func claimCodeManifestData(at url: URL) throws -> [[String: AnyHashable]] {
        let data = try Data(contentsOf: url)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return payload?["units"] as? [[String: AnyHashable]] ?? []
    }
}

private let goldenVectors: [GoldenVector] = [
    GoldenVector(
        unitID: 0,
        hash: "1500739fcaa8af0f5a34e5c02438cb81f795c7ae5ea5601daf1b6f3560f1a837",
        initialPermutation: [3, 14, 4, 10, 12, 8, 7, 13, 9, 2, 1, 5, 16, 11, 15, 6],
        firstEventPermutation: [3, 14, 4, 10, 12, 7, 8, 13, 9, 2, 1, 5, 16, 11, 15, 6],
        lastEventPermutation: [13, 3, 2, 16, 8, 10, 11, 5, 12, 6, 7, 9, 1, 15, 14, 4]
    ),
    GoldenVector(
        unitID: 1,
        hash: "67693a38c1b5946a2670af7c769a7c18ed80d01356266c687f5a19b7be235572",
        initialPermutation: [9, 4, 16, 3, 11, 2, 14, 8, 1, 7, 6, 12, 10, 13, 15, 5],
        firstEventPermutation: [9, 4, 3, 16, 11, 2, 14, 8, 1, 7, 6, 12, 10, 13, 15, 5],
        lastEventPermutation: [13, 3, 2, 16, 8, 10, 11, 5, 12, 6, 7, 9, 1, 15, 14, 4]
    ),
    GoldenVector(
        unitID: 42,
        hash: "edeb73e5ff5800a391479e777a53a5e1cdf44fe1aa6c435887188ae31acc67b9",
        initialPermutation: [15, 16, 3, 7, 14, 2, 13, 4, 8, 10, 9, 5, 12, 11, 6, 1],
        firstEventPermutation: [15, 16, 3, 6, 14, 2, 13, 4, 8, 10, 9, 5, 12, 11, 7, 1],
        lastEventPermutation: [13, 3, 2, 16, 8, 10, 11, 5, 12, 6, 7, 9, 1, 15, 14, 4]
    )
]

private struct GoldenVector {
    let unitID: Int
    let hash: String
    let initialPermutation: [UInt8]
    let firstEventPermutation: [UInt8]
    let lastEventPermutation: [UInt8]
}
