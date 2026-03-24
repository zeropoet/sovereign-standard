public struct InvariantResult {
    public let isSatisfied: Bool
    public let deviation: Int

    public init(isSatisfied: Bool, deviation: Int) {
        self.isSatisfied = isSatisfied
        self.deviation = deviation
    }
}

public struct InvariantEvaluator {
    /// Phase 3 section 2: Creates an invariant evaluator for 4x4 permutation sums.
    public init() {}

    /// Phase 3 sections 3, 4, and 5: Evaluates row/column/diagonal sum invariants against target 34.
    public func evaluate(_ permutation: Permutation) -> InvariantResult {
        let p = permutation.values.map(Int.init)

        let sums: [Int] = [
            p[0] + p[1] + p[2] + p[3],
            p[4] + p[5] + p[6] + p[7],
            p[8] + p[9] + p[10] + p[11],
            p[12] + p[13] + p[14] + p[15],

            p[0] + p[4] + p[8] + p[12],
            p[1] + p[5] + p[9] + p[13],
            p[2] + p[6] + p[10] + p[14],
            p[3] + p[7] + p[11] + p[15],

            p[0] + p[5] + p[10] + p[15],
            p[3] + p[6] + p[9] + p[12]
        ]

        let deviation = sums.reduce(0) { partial, sum in
            partial + abs(sum - 34)
        }

        return InvariantResult(isSatisfied: deviation == 0, deviation: deviation)
    }
}
