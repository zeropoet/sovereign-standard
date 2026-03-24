public struct AdjacencyGraph {
    public let adjacency: [UInt8: Set<UInt8>]

    /// Phase 2 sections 2 and 3: Derives local 8-neighborhood adjacency from a canonical 4x4 permutation layout.
    public init(from canonical: Permutation) {
        var valueToIndex: [UInt8: Int] = [:]
        valueToIndex.reserveCapacity(16)

        for (index, value) in canonical.values.enumerated() {
            valueToIndex[value] = index
        }

        var derivedAdjacency: [UInt8: Set<UInt8>] = [:]
        derivedAdjacency.reserveCapacity(16)

        for value in UInt8(1)...UInt8(16) {
            derivedAdjacency[value] = []

            guard let i = valueToIndex[value] else {
                continue
            }

            let rowI = i / 4
            let colI = i % 4

            for j in 0..<16 where j != i {
                let rowJ = j / 4
                let colJ = j % 4

                if abs(rowI - rowJ) <= 1 && abs(colI - colJ) <= 1 {
                    let neighborValue = canonical.values[j]
                    derivedAdjacency[value, default: []].insert(neighborValue)
                }
            }
        }

        self.adjacency = derivedAdjacency
    }
}
