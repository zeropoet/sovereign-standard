import XCTest
@testable import FoldKernel

final class AdjacencyTests: XCTestCase {
    func testAllValuesPresent() {
        let graph = AdjacencyGraph(from: CanonicalSquare.S0)
        XCTAssertEqual(graph.adjacency.count, 16)
    }

    func testDegreeCounts() {
        let graph = AdjacencyGraph(from: CanonicalSquare.S0)
        let degrees = graph.adjacency.values.map { $0.count }

        XCTAssertEqual(degrees.filter { $0 == 3 }.count, 4)
        XCTAssertEqual(degrees.filter { $0 == 5 }.count, 8)
        XCTAssertEqual(degrees.filter { $0 == 8 }.count, 4)
    }

    func testKnownCaseVerification() {
        let graph = AdjacencyGraph(from: CanonicalSquare.S0)

        XCTAssertEqual(graph.adjacency[10], Set<UInt8>([13, 3, 2, 8, 11, 12, 6, 7]))
        XCTAssertEqual(graph.adjacency[13], Set<UInt8>([3, 8, 10]))
    }

    func testSymmetryStability() {
        let canonicalAdjacency = AdjacencyGraph(from: CanonicalSquare.S0).adjacency

        for transform in SymmetryTransform.allCases {
            let transformed = transform.apply(to: CanonicalSquare.S0)
            let transformedAdjacency = AdjacencyGraph(from: transformed).adjacency
            XCTAssertEqual(transformedAdjacency, canonicalAdjacency)
        }
    }
}
