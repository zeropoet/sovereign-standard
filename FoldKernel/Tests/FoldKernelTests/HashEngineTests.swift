import XCTest
@testable import FoldKernel

final class HashEngineTests: XCTestCase {
    func testKnownMemorySignatureHash() {
        let engine = HashEngine()
        let signature: [UInt8] = [0x01, 0x02, 0x03]

        let expected = bytes(fromHex: "0c6ed2168c4bbc60aabd871964c43d515d2ffab1b9329d76dc741a72ac8cfe77")
        XCTAssertEqual(engine.convergenceHash(memorySignature: signature), expected)
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
