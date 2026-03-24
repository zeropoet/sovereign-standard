import XCTest
@testable import FoldKernel

final class KeccakTests: XCTestCase {
    func testEmptyInputVector() {
        let keccak = Keccak256()
        let expected = bytes(fromHex: "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")

        XCTAssertEqual(keccak.hash([]), expected)
    }

    func testABCTestVector() {
        let keccak = Keccak256()
        let expected = bytes(fromHex: "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45")

        XCTAssertEqual(keccak.hash([0x61, 0x62, 0x63]), expected)
    }

    func testDeterminism() {
        let keccak = Keccak256()
        let input = Array("FoldKernel".utf8)

        XCTAssertEqual(keccak.hash(input), keccak.hash(input))
    }

    private func bytes(fromHex hex: String) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)

        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let pair = String(hex[index..<next])
            bytes.append(UInt8(pair, radix: 16)!)
            index = next
        }

        return bytes
    }
}
