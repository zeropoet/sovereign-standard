extension Permutation: Hashable {
    public static func == (lhs: Permutation, rhs: Permutation) -> Bool {
        lhs.values == rhs.values
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(values)
    }
}

public struct CanonicalDistance {
    private let canonicalSet: Set<Permutation>

    /// Phase 4 section 2: Initializes the metric with an injected canonical set.
    public init(canonicalSet: Set<Permutation>) {
        self.canonicalSet = canonicalSet
    }

    /// Phase 4 section 3: Returns minimum positional Hamming distance to the injected canonical set.
    public func distance(from permutation: Permutation) -> Int {
        var minimumDistance = Int.max

        for canonical in canonicalSet {
            let hammingDistance = zip(permutation.values, canonical.values).reduce(0) { count, pair in
                count + (pair.0 == pair.1 ? 0 : 1)
            }

            if hammingDistance < minimumDistance {
                minimumDistance = hammingDistance
            }
        }

        return minimumDistance
    }
}
