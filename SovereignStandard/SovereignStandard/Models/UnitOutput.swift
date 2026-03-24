import Foundation
import FoldKernel

struct UnitOutput {
    let unitID: Int
    let permutation: Permutation
    let canonicalDistance: Int
    let events: [FoldEvent]
    let memory: [UInt8]
    let hash: String
    let sigilSVG: String
}

extension UnitOutput: Encodable {
    enum CodingKeys: String, CodingKey {
        case unitID = "unit_id"
        case permutation
        case canonicalDistance = "canonical_distance"
        case events
        case memory
        case hash
        case sigilSVG = "sigil_svg"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unitID, forKey: .unitID)
        try container.encode(permutation.values, forKey: .permutation)
        try container.encode(canonicalDistance, forKey: .canonicalDistance)
        try container.encode(events.map(UnitEvent.init), forKey: .events)
        try container.encode(memory, forKey: .memory)
        try container.encode(hash, forKey: .hash)
        try container.encode(sigilSVG, forKey: .sigilSVG)
    }
}

private struct UnitEvent: Encodable {
    let type: String
    let permutation: [UInt8]?
    let bitmask: UInt8?
    let topology: UInt8?

    init(_ event: FoldEvent) {
        switch event {
        case .permutationCommit(let permutation):
            type = "permutation_commit"
            self.permutation = permutation.values
            bitmask = nil
            topology = nil
        case .lockStateChange(let state):
            type = "lock_state_change"
            permutation = nil
            bitmask = state
            topology = nil
        case .foldTopologyChange(let value):
            type = "fold_topology_change"
            permutation = nil
            bitmask = nil
            topology = value
        }
    }
}
