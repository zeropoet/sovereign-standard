import Foundation
import FoldKernel
import SigilEngine

struct SovereignEngine {
    let canonicalSet: Set<Permutation>
    let adjacencyGraph: AdjacencyGraph
    let invariantEvaluator: InvariantEvaluator
    let canonicalDistance: CanonicalDistance
    let convergenceEvaluator: ConvergenceEvaluator
    let memoryEncoder: MemoryEncoder
    let hashEngine: HashEngine
    let sigilGenerator: SigilGenerator
    let svgExporter: SVGExporter
    let pathGenerator: PathGenerator

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
        pathGenerator = PathGenerator()
    }

    func generateUnit(unitID: Int) -> UnitOutput {
        let start = permutationFromUnitID(unitID)
        let path = pathGenerator.generatePath(from: start)
        let events = path.map(FoldEvent.permutationCommit)
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
            permutation: start,
            events: events,
            memory: memory,
            hash: hash,
            sigilSVG: svg
        )
    }
}
