import Foundation
import FoldKernel

struct SovereignWalker {
    static let version = "SovereignWalker-1.0.0"
    static let stepCount = 64

    private enum Weight {
        static let invariantDeviation = 3
        static let canonicalDistance = 2
        static let adjacencyDelta = 1
    }

    private let canonicalPermutation = CanonicalSquare.S0
    private let adjacencyGraph: AdjacencyGraph
    private let invariantEvaluator: InvariantEvaluator
    private let canonicalDistance: CanonicalDistance
    private let hashEngine = Keccak256()

    init(
        adjacencyGraph: AdjacencyGraph,
        invariantEvaluator: InvariantEvaluator,
        canonicalDistance: CanonicalDistance
    ) {
        self.adjacencyGraph = adjacencyGraph
        self.invariantEvaluator = invariantEvaluator
        self.canonicalDistance = canonicalDistance
    }

    func generateTraversal(unitNumber: UInt64) throws -> WalkerTraversal {
        var entropy = DeterministicEntropyStream(unitNumber: unitNumber, hashEngine: hashEngine)
        var currentPermutation = canonicalPermutation
        var forwardPath: [Permutation] = []
        forwardPath.reserveCapacity(Self.stepCount)

        for _ in 0..<Self.stepCount {
            let orderedCandidates = try orderedCandidates(from: currentPermutation)
            let selectedIndex = Int(entropy.nextByte()) % orderedCandidates.count
            let chosenMove = orderedCandidates[selectedIndex]

            currentPermutation = chosenMove.permutation
            forwardPath.append(currentPermutation)
        }

        let initialPermutation = forwardPath.last ?? canonicalPermutation
        let reversedPath = Array(forwardPath.dropLast().reversed()) + [canonicalPermutation]
        let events = reversedPath.map(FoldEvent.permutationCommit)

        return WalkerTraversal(
            initialPermutation: initialPermutation,
            events: events
        )
    }

    private func orderedCandidates(from permutation: Permutation) throws -> [ScoredCandidate] {
        var candidates: [ScoredCandidate] = []
        candidates.reserveCapacity(120)

        for i in 0..<15 {
            for j in (i + 1)..<16 {
                let candidatePermutation = try swapped(permutation, i, j)
                let invariantDeviation = invariantEvaluator.evaluate(candidatePermutation).deviation
                let distance = canonicalDistance.distance(from: candidatePermutation)
                let adjacencyDelta = adjacencyDelta(from: candidatePermutation)
                let score =
                    (invariantDeviation * Weight.invariantDeviation) +
                    (distance * Weight.canonicalDistance) +
                    (adjacencyDelta * Weight.adjacencyDelta)

                candidates.append(
                    ScoredCandidate(
                        sourceIndex: i,
                        destinationIndex: j,
                        permutation: candidatePermutation,
                        score: score
                    )
                )
            }
        }

        return candidates.sorted {
            if $0.score != $1.score {
                return $0.score < $1.score
            }

            if $0.sourceIndex != $1.sourceIndex {
                return $0.sourceIndex < $1.sourceIndex
            }

            return $0.destinationIndex < $1.destinationIndex
        }
    }

    private func swapped(_ permutation: Permutation, _ i: Int, _ j: Int) throws -> Permutation {
        var values = permutation.values
        values.swapAt(i, j)
        return try Permutation(values)
    }

    private func adjacencyDelta(from permutation: Permutation) -> Int {
        let candidateAdjacency = AdjacencyGraph(from: permutation).adjacency
        var delta = 0

        for value in UInt8(1)...UInt8(16) {
            let candidateNeighbors = candidateAdjacency[value] ?? []
            let canonicalNeighbors = adjacencyGraph.adjacency[value] ?? []
            delta += candidateNeighbors.symmetricDifference(canonicalNeighbors).count
        }

        return delta
    }
}

struct WalkerTraversal {
    let initialPermutation: Permutation
    let events: [FoldEvent]
}

private struct ScoredCandidate {
    let sourceIndex: Int
    let destinationIndex: Int
    let permutation: Permutation
    let score: Int
}

private struct DeterministicEntropyStream {
    private var block: [UInt8]
    private var nextIndex: Int = 0
    private let hashEngine: Keccak256

    init(unitNumber: UInt64, hashEngine: Keccak256) {
        let versionBytes = Array(SovereignWalker.version.utf8)
        let seedBytes = versionBytes + unitNumber.littleEndianBytes
        self.hashEngine = hashEngine
        self.block = hashEngine.hash(seedBytes)
    }

    mutating func nextByte() -> UInt8 {
        if nextIndex == block.count {
            block = hashEngine.hash(block)
            nextIndex = 0
        }

        defer { nextIndex += 1 }
        return block[nextIndex]
    }
}

private extension UInt64 {
    var littleEndianBytes: [UInt8] {
        let value = littleEndian
        return withUnsafeBytes(of: value) { Array($0) }
    }
}
