public struct Keccak256 {
    private let rateBytes = 136

    /// Phase 7 section 2: Creates a pure Swift Keccak-256 hasher.
    public init() {}

    /// Phase 7 sections 2 and 3: Hashes bytes using Keccak-256 sponge construction and Keccak-f[1600].
    public func hash(_ bytes: [UInt8]) -> [UInt8] {
        var state = Array(repeating: UInt64(0), count: 25)

        var offset = 0
        while offset + rateBytes <= bytes.count {
            absorbBlock(bytes[offset..<(offset + rateBytes)], into: &state)
            keccakF1600(&state)
            offset += rateBytes
        }

        let remainingCount = bytes.count - offset
        var finalBlock = Array(repeating: UInt8(0), count: rateBytes)
        if remainingCount > 0 {
            finalBlock[0..<remainingCount] = bytes[offset..<bytes.count]
        }
        finalBlock[remainingCount] = 0x01
        finalBlock[rateBytes - 1] |= 0x80

        absorbBlock(finalBlock[0..<rateBytes], into: &state)
        keccakF1600(&state)

        var output: [UInt8] = []
        output.reserveCapacity(32)

        while output.count < 32 {
            for i in 0..<rateBytes where output.count < 32 {
                let lane = i / 8
                let shift = UInt64((i % 8) * 8)
                output.append(UInt8((state[lane] >> shift) & 0xFF))
            }

            if output.count < 32 {
                keccakF1600(&state)
            }
        }

        return output
    }

    private func absorbBlock(_ block: ArraySlice<UInt8>, into state: inout [UInt64]) {
        for (index, byte) in block.enumerated() {
            let lane = index / 8
            let shift = UInt64((index % 8) * 8)
            state[lane] ^= UInt64(byte) << shift
        }
    }

    private func keccakF1600(_ state: inout [UInt64]) {
        for round in 0..<24 {
            var c = Array(repeating: UInt64(0), count: 5)
            for x in 0..<5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }

            var d = Array(repeating: UInt64(0), count: 5)
            for x in 0..<5 {
                d[x] = c[(x + 4) % 5] ^ rotateLeft(c[(x + 1) % 5], by: 1)
            }

            for y in 0..<5 {
                for x in 0..<5 {
                    state[x + 5 * y] ^= d[x]
                }
            }

            var b = Array(repeating: UInt64(0), count: 25)
            for y in 0..<5 {
                for x in 0..<5 {
                    let index = x + 5 * y
                    let newX = y
                    let newY = (2 * x + 3 * y) % 5
                    b[newX + 5 * newY] = rotateLeft(state[index], by: Self.rotationOffsets[index])
                }
            }

            for y in 0..<5 {
                for x in 0..<5 {
                    state[x + 5 * y] = b[x + 5 * y] ^ ((~b[(x + 1) % 5 + 5 * y]) & b[(x + 2) % 5 + 5 * y])
                }
            }

            state[0] ^= Self.roundConstants[round]
        }
    }

    private func rotateLeft(_ value: UInt64, by offset: Int) -> UInt64 {
        let n = offset & 63
        if n == 0 {
            return value
        }
        return (value << n) | (value >> (64 - n))
    }

    private static let rotationOffsets: [Int] = [
        0, 1, 62, 28, 27,
        36, 44, 6, 55, 20,
        3, 10, 43, 25, 39,
        41, 45, 15, 21, 8,
        18, 2, 61, 56, 14
    ]

    private static let roundConstants: [UInt64] = [
        0x0000000000000001,
        0x0000000000008082,
        0x800000000000808A,
        0x8000000080008000,
        0x000000000000808B,
        0x0000000080000001,
        0x8000000080008081,
        0x8000000000008009,
        0x000000000000008A,
        0x0000000000000088,
        0x0000000080008009,
        0x000000008000000A,
        0x000000008000808B,
        0x800000000000008B,
        0x8000000000008089,
        0x8000000000008003,
        0x8000000000008002,
        0x8000000000000080,
        0x000000000000800A,
        0x800000008000000A,
        0x8000000080008081,
        0x8000000000008080,
        0x0000000080000001,
        0x8000000080008008
    ]
}
