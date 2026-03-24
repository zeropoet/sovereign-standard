import XCTest
@testable import FoldKernel

final class PermutationTests: XCTestCase {
    func testAcceptsAscendingSequence() throws {
        let expected = Array(1...16).map(UInt8.init)
        let permutation = try Permutation(expected)
        XCTAssertEqual(permutation.values, expected)
    }

    func testAcceptsCanonicalS0() throws {
        let expected: [UInt8] = [
            13, 3, 2, 16,
            8, 10, 11, 5,
            12, 6, 7, 9,
            1, 15, 14, 4
        ]
        let permutation = try Permutation(expected)
        XCTAssertEqual(permutation.values, expected)
    }

    func testRejectsDuplicates() {
        XCTAssertThrowsError(try Permutation([
            1, 1, 2, 3,
            4, 5, 6, 7,
            8, 9, 10, 11,
            12, 13, 14, 15
        ])) { error in
            XCTAssertEqual(error as? PermutationError, .duplicateValue)
        }
    }

    func testRejectsOutOfRange() {
        XCTAssertThrowsError(try Permutation([
            0, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])) { error in
            XCTAssertEqual(error as? PermutationError, .outOfRange)
        }
    }

    func testRejectsMissingValues() {
        XCTAssertThrowsError(try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15
        ])) { error in
            XCTAssertEqual(error as? PermutationError, .invalidLength)
        }
    }
}
