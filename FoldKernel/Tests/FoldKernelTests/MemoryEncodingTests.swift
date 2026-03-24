import XCTest
@testable import FoldKernel

final class MemoryEncodingTests: XCTestCase {
    func testPermutationCommitLength() throws {
        let encoder = MemoryEncoder()
        let permutation = try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])

        let bytes = encoder.encode([.permutationCommit(permutation)])
        XCTAssertEqual(bytes.count, 17)
    }

    func testLockStateChangeLength() {
        let encoder = MemoryEncoder()
        let bytes = encoder.encode([.lockStateChange(0b00000111)])

        XCTAssertEqual(bytes.count, 2)
    }

    func testCombinedSequenceLength() throws {
        let encoder = MemoryEncoder()
        let permutation = try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])

        let events: [FoldEvent] = [
            .permutationCommit(permutation),
            .lockStateChange(0b00000111),
            .foldTopologyChange(0x01)
        ]

        let bytes = encoder.encode(events)
        XCTAssertEqual(bytes.count, 21)
    }

    func testDeterminism() throws {
        let encoder = MemoryEncoder()
        let permutation = try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])

        let events: [FoldEvent] = [
            .permutationCommit(permutation),
            .lockStateChange(0b00000111),
            .foldTopologyChange(0x01)
        ]

        let first = encoder.encode(events)
        let second = encoder.encode(events)
        XCTAssertEqual(first, second)
    }

    func testByteExactness() throws {
        let encoder = MemoryEncoder()
        let permutation = try Permutation([
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        ])

        let events: [FoldEvent] = [
            .permutationCommit(permutation),
            .lockStateChange(0x07),
            .foldTopologyChange(0x01)
        ]

        let expected: [UInt8] = [
            0x01,
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16,
            0x02, 0x07,
            0x03, 0x01
        ]

        let bytes = encoder.encode(events)
        XCTAssertEqual(bytes, expected)
    }
}
