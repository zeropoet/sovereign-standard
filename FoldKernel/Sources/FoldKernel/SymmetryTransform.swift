public enum SymmetryTransform: CaseIterable {
    case identity
    case rotate90
    case rotate180
    case rotate270
    case reflectHorizontal
    case reflectVertical
    case reflectMainDiagonal
    case reflectAntiDiagonal

    /// Spec sections 5, 6, and 7: Applies the fixed transform mapping with `new[i] = old[mapping[i]]`.
    public func apply(to permutation: Permutation) -> Permutation {
        let mapping: [Int]

        switch self {
        case .identity:
            mapping = Self.identityMapping
        case .rotate90:
            mapping = Self.rotate90Mapping
        case .rotate180:
            mapping = Self.rotate180Mapping
        case .rotate270:
            mapping = Self.rotate270Mapping
        case .reflectHorizontal:
            mapping = Self.reflectHorizontalMapping
        case .reflectVertical:
            mapping = Self.reflectVerticalMapping
        case .reflectMainDiagonal:
            mapping = Self.reflectMainDiagonalMapping
        case .reflectAntiDiagonal:
            mapping = Self.reflectAntiDiagonalMapping
        }

        var transformed = Array(repeating: UInt8(0), count: 16)
        for i in 0..<16 {
            transformed[i] = permutation.values[mapping[i]]
        }

        return Permutation(validated: transformed)
    }

    private static let identityMapping = [
        0, 1, 2, 3,
        4, 5, 6, 7,
        8, 9, 10, 11,
        12, 13, 14, 15
    ]

    private static let rotate90Mapping = [
        12, 8, 4, 0,
        13, 9, 5, 1,
        14, 10, 6, 2,
        15, 11, 7, 3
    ]

    private static let rotate180Mapping = [
        15, 14, 13, 12,
        11, 10, 9, 8,
        7, 6, 5, 4,
        3, 2, 1, 0
    ]

    private static let rotate270Mapping = [
        3, 7, 11, 15,
        2, 6, 10, 14,
        1, 5, 9, 13,
        0, 4, 8, 12
    ]

    private static let reflectHorizontalMapping = [
        12, 13, 14, 15,
        8, 9, 10, 11,
        4, 5, 6, 7,
        0, 1, 2, 3
    ]

    private static let reflectVerticalMapping = [
        3, 2, 1, 0,
        7, 6, 5, 4,
        11, 10, 9, 8,
        15, 14, 13, 12
    ]

    private static let reflectMainDiagonalMapping = [
        0, 4, 8, 12,
        1, 5, 9, 13,
        2, 6, 10, 14,
        3, 7, 11, 15
    ]

    private static let reflectAntiDiagonalMapping = [
        15, 11, 7, 3,
        14, 10, 6, 2,
        13, 9, 5, 1,
        12, 8, 4, 0
    ]
}
