import Foundation
import FoldKernel

struct PathGenerator {
    private let canonical = CanonicalSquare.S0

    func generatePath(from permutation: Permutation) -> [Permutation] {
        var path = [permutation]
        var current = permutation

        while current != canonical {
            var values = current.values

            guard let nextSwap = nextSwapIndices(for: values) else {
                break
            }

            values.swapAt(nextSwap.source, nextSwap.destination)
            let next = try! Permutation(values)

            if next == current {
                break
            }

            path.append(next)
            current = next
        }

        return path
    }

    private func nextSwapIndices(for values: [UInt8]) -> (source: Int, destination: Int)? {
        for destination in values.indices where values[destination] != canonical.values[destination] {
            let targetValue = canonical.values[destination]
            guard let source = values.firstIndex(of: targetValue) else {
                continue
            }

            return (source, destination)
        }

        return nil
    }
}

func permutationFromUnitID(_ id: Int) -> Permutation {
    var values = Array(UInt8(1)...UInt8(16))
    seededShuffle(&values, seed: UInt64(bitPattern: Int64(id)))
    return try! Permutation(values)
}

private func seededShuffle<T>(_ values: inout [T], seed: UInt64) {
    var generator = SeededGenerator(seed: seed == 0 ? 0x9E3779B97F4A7C15 : seed)

    for index in stride(from: values.count - 1, through: 1, by: -1) {
        let swapIndex = Int(generator.next() % UInt64(index + 1))
        values.swapAt(index, swapIndex)
    }
}

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}
