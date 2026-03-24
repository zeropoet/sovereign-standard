public enum PermutationError: Error, Equatable {
    case invalidLength
    case outOfRange
    case duplicateValue
    case missingValues
}

public struct Permutation {
    public let values: [UInt8]

    /// Spec section 3: Validates a 4x4 permutation of values 1...16 with no duplicates or missing values.
    public init(_ values: [UInt8]) throws {
        guard values.count == 16 else {
            throw PermutationError.invalidLength
        }

        var seen = Array(repeating: false, count: 16)
        for value in values {
            guard (1...16).contains(Int(value)) else {
                throw PermutationError.outOfRange
            }

            let index = Int(value - 1)
            if seen[index] {
                throw PermutationError.duplicateValue
            }
            seen[index] = true
        }

        guard seen.allSatisfy({ $0 }) else {
            throw PermutationError.missingValues
        }

        self.values = values
    }

    init(validated values: [UInt8]) {
        self.values = values
    }
}
