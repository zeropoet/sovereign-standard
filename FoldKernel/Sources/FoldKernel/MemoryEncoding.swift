public enum FoldEvent {
    case permutationCommit(Permutation)
    case lockStateChange(UInt8)
    case foldTopologyChange(UInt8)
}

public struct MemoryEncoder {
    /// Phase 6 section 3: Creates a stateless encoder for fold events.
    public init() {}

    /// Phase 6 sections 3 and 4: Encodes events as raw concatenated bytes in input order.
    public func encode(_ events: [FoldEvent]) -> [UInt8] {
        var bytes: [UInt8] = []

        for event in events {
            switch event {
            case .permutationCommit(let permutation):
                bytes.append(0x01)
                bytes.append(contentsOf: permutation.values)
            case .lockStateChange(let bitmask):
                bytes.append(0x02)
                bytes.append(bitmask)
            case .foldTopologyChange(let topology):
                bytes.append(0x03)
                bytes.append(topology)
            }
        }

        return bytes
    }
}
