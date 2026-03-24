import XCTest
@testable import FoldKernel

final class InvariantTests: XCTestCase {
    func testCanonicalS0SatisfiesInvariant() {
        let evaluator = InvariantEvaluator()
        let result = evaluator.evaluate(CanonicalSquare.S0)

        XCTAssertTrue(result.isSatisfied)
        XCTAssertEqual(result.deviation, 0)
    }

    func testAscendingInitialP0DoesNotSatisfyInvariant() throws {
        let evaluator = InvariantEvaluator()
        let ascending = try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])

        let result = evaluator.evaluate(ascending)
        XCTAssertFalse(result.isSatisfied)
        XCTAssertGreaterThan(result.deviation, 0)
    }

    func testSingleSwapCreatesDeviation() {
        let evaluator = InvariantEvaluator()
        var swappedValues = CanonicalSquare.S0.values
        swappedValues.swapAt(0, 1)
        let swapped = Permutation(validated: swappedValues)

        let result = evaluator.evaluate(swapped)
        XCTAssertFalse(result.isSatisfied)
        XCTAssertGreaterThan(result.deviation, 0)
    }

    func testDeterminism() {
        let evaluator = InvariantEvaluator()
        let first = evaluator.evaluate(CanonicalSquare.S0)
        let second = evaluator.evaluate(CanonicalSquare.S0)

        XCTAssertEqual(first.isSatisfied, second.isSatisfied)
        XCTAssertEqual(first.deviation, second.deviation)
    }
}
