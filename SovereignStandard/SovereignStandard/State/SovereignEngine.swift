import Foundation
import FoldKernel
import SigilEngine

struct SovereignEngine {
    static let kernelVersion = "FoldKernel-1.0.0"

    let canonicalSet: Set<Permutation>
    let adjacencyGraph: AdjacencyGraph
    let invariantEvaluator: InvariantEvaluator
    let canonicalDistance: CanonicalDistance
    let convergenceEvaluator: ConvergenceEvaluator
    let memoryEncoder: MemoryEncoder
    let hashEngine: HashEngine
    let sigilGenerator: SigilGenerator
    let svgExporter: SVGExporter
    let walker: SovereignWalker

    init() {
        let s0 = CanonicalSquare.S0
        let orbit = Set(SymmetryTransform.allCases.map { $0.apply(to: s0) })
        let adjacencyGraph = AdjacencyGraph(from: s0)
        let invariantEvaluator = InvariantEvaluator()
        let canonicalDistance = CanonicalDistance(canonicalSet: orbit)

        self.canonicalSet = orbit
        self.adjacencyGraph = adjacencyGraph
        self.invariantEvaluator = invariantEvaluator
        self.canonicalDistance = canonicalDistance
        convergenceEvaluator = ConvergenceEvaluator(
            canonicalSet: orbit,
            adjacencyGraph: adjacencyGraph,
            invariantEvaluator: invariantEvaluator,
            canonicalDistance: canonicalDistance
        )
        memoryEncoder = MemoryEncoder()
        hashEngine = HashEngine()
        sigilGenerator = SigilGenerator()
        svgExporter = SVGExporter()
        walker = SovereignWalker(
            adjacencyGraph: adjacencyGraph,
            invariantEvaluator: invariantEvaluator,
            canonicalDistance: canonicalDistance
        )
    }

    func generateUnit(unitID: Int) throws -> UnitOutput {
        let unitNumber = try validatedUnitNumber(from: unitID)
        let traversal = try walker.generateTraversal(unitNumber: unitNumber)
        let initialPermutation = traversal.initialPermutation
        let startCanonicalDistance = canonicalDistance.distance(from: initialPermutation)
        let events = traversal.events
        let memory = memoryEncoder.encode(events)
        let hash = hashEngine
            .convergenceHash(memorySignature: memory)
            .map { String(format: "%02x", $0) }
            .joined()
        let sigil = sigilGenerator.generate(
            events: events,
            canonicalDistance: canonicalDistance,
            convergenceEvaluator: convergenceEvaluator
        )
        let svg = svgExporter.export(sigil)

        return UnitOutput(
            unitID: unitID,
            walkerVersion: SovereignWalker.version,
            kernelVersion: Self.kernelVersion,
            stepCount: SovereignWalker.stepCount,
            permutation: initialPermutation,
            canonicalDistance: startCanonicalDistance,
            events: events,
            memory: memory,
            hash: hash,
            sigilSVG: svg
        )
    }

    private func validatedUnitNumber(from unitID: Int) throws -> UInt64 {
        guard unitID >= 0, let unitNumber = UInt64(exactly: unitID) else {
            throw SovereignEngineError.invalidUnitID(unitID)
        }

        return unitNumber
    }
}

enum SovereignEngineError: Error, LocalizedError {
    case invalidUnitID(Int)

    var errorDescription: String? {
        switch self {
        case .invalidUnitID(let unitID):
            return "Unit id must be a non-negative 64-bit value. Received \(unitID)."
        }
    }
}
