import XCTest
@testable import FoldKernel

final class ConvergenceTests: XCTestCase {
    private var canonicalSet: Set<Permutation> {
        Set(SymmetryTransform.allCases.map { $0.apply(to: CanonicalSquare.S0) })
    }

    private func makeEvaluator() -> ConvergenceEvaluator {
        let set = canonicalSet
        let adjacency = AdjacencyGraph(from: CanonicalSquare.S0)
        let invariant = InvariantEvaluator()
        let distance = CanonicalDistance(canonicalSet: set)

        return ConvergenceEvaluator(
            canonicalSet: set,
            adjacencyGraph: adjacency,
            invariantEvaluator: invariant,
            canonicalDistance: distance
        )
    }

    func testCanonicalOrbitSatisfiesAllStructuralChecks() {
        let evaluator = makeEvaluator()

        for canonical in canonicalSet {
            let state = evaluator.evaluate(canonical)
            XCTAssertTrue(state.isCanonical)
            XCTAssertTrue(state.sumSatisfied)
            XCTAssertTrue(state.adjacencySatisfied)
        }
    }

    func testAscendingP0FailsAllChecks() throws {
        let evaluator = makeEvaluator()
        let ascending = try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])

        let state = evaluator.evaluate(ascending)
        XCTAssertFalse(state.isCanonical)
        XCTAssertFalse(state.sumSatisfied)
        XCTAssertFalse(state.adjacencySatisfied)
    }

    func testSwapInS0FailsAllChecks() {
        let evaluator = makeEvaluator()
        var swappedValues = CanonicalSquare.S0.values
        swappedValues.swapAt(0, 1)
        let swapped = Permutation(validated: swappedValues)

        let state = evaluator.evaluate(swapped)
        XCTAssertFalse(state.isCanonical)
        XCTAssertFalse(state.sumSatisfied)
        XCTAssertFalse(state.adjacencySatisfied)
    }

    func testDeterminism() {
        let evaluator = makeEvaluator()
        let first = evaluator.evaluate(CanonicalSquare.S0)
        let second = evaluator.evaluate(CanonicalSquare.S0)

        XCTAssertEqual(first.isCanonical, second.isCanonical)
        XCTAssertEqual(first.sumSatisfied, second.sumSatisfied)
        XCTAssertEqual(first.adjacencySatisfied, second.adjacencySatisfied)
    }
}
