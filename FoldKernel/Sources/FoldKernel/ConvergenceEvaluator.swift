public struct ConvergenceState {
    public let isCanonical: Bool
    public let sumSatisfied: Bool
    public let adjacencySatisfied: Bool

    public init(isCanonical: Bool, sumSatisfied: Bool, adjacencySatisfied: Bool) {
        self.isCanonical = isCanonical
        self.sumSatisfied = sumSatisfied
        self.adjacencySatisfied = adjacencySatisfied
    }
}

public struct ConvergenceEvaluator {
    private let canonicalSet: Set<Permutation>
    private let adjacencyGraph: AdjacencyGraph
    private let invariantEvaluator: InvariantEvaluator
    private let canonicalDistance: CanonicalDistance

    /// Phase 5 section 2: Initializes convergence dependencies for structural evaluation.
    public init(
        canonicalSet: Set<Permutation>,
        adjacencyGraph: AdjacencyGraph,
        invariantEvaluator: InvariantEvaluator,
        canonicalDistance: CanonicalDistance
    ) {
        self.canonicalSet = canonicalSet
        self.adjacencyGraph = adjacencyGraph
        self.invariantEvaluator = invariantEvaluator
        self.canonicalDistance = canonicalDistance
    }

    /// Phase 5 section 3: Evaluates canonical distance, sum invariant, and adjacency equality invariants.
    public func evaluate(_ permutation: Permutation) -> ConvergenceState {
        _ = canonicalSet

        let isCanonical = canonicalDistance.distance(from: permutation) == 0
        let sumSatisfied = invariantEvaluator.evaluate(permutation).isSatisfied

        let currentAdjacency = AdjacencyGraph(from: permutation).adjacency
        var adjacencySatisfied = true

        for value in UInt8(1)...UInt8(16) {
            let current = currentAdjacency[value] ?? []
            let baseline = adjacencyGraph.adjacency[value] ?? []
            if current != baseline {
                adjacencySatisfied = false
                break
            }
        }

        return ConvergenceState(
            isCanonical: isCanonical,
            sumSatisfied: sumSatisfied,
            adjacencySatisfied: adjacencySatisfied
        )
    }
}
