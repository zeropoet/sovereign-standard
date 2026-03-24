import XCTest
@testable import FoldKernel

final class CanonicalDistanceTests: XCTestCase {
    private var canonicalSet: Set<Permutation> {
        Set(SymmetryTransform.allCases.map { $0.apply(to: CanonicalSquare.S0) })
    }

    func testCanonicalDistanceOfS0OrbitIsZero() {
        let metric = CanonicalDistance(canonicalSet: canonicalSet)

        for canonical in canonicalSet {
            XCTAssertEqual(metric.distance(from: canonical), 0)
        }
    }

    func testAscendingP0DistanceIsGreaterThanZero() throws {
        let metric = CanonicalDistance(canonicalSet: canonicalSet)
        let ascending = try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])

        XCTAssertGreaterThan(metric.distance(from: ascending), 0)
    }

    func testSingleSwapFromS0DistanceIsGreaterThanZero() {
        let metric = CanonicalDistance(canonicalSet: canonicalSet)
        var swappedValues = CanonicalSquare.S0.values
        swappedValues.swapAt(0, 1)
        let swapped = Permutation(validated: swappedValues)

        XCTAssertGreaterThan(metric.distance(from: swapped), 0)
    }

    func testDeterminism() {
        let metric = CanonicalDistance(canonicalSet: canonicalSet)
        let first = metric.distance(from: CanonicalSquare.S0)
        let second = metric.distance(from: CanonicalSquare.S0)

        XCTAssertEqual(first, second)
    }
}
