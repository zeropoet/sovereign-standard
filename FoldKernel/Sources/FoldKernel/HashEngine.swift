public struct HashEngine {
    /// Phase 7 section 7: Creates a hash engine for convergence memory signatures.
    public init() {}

    /// Phase 7 section 7: Prefixes version bytes and returns Keccak-256 digest of the combined payload.
    public func convergenceHash(memorySignature: [UInt8]) -> [UInt8] {
        let versionBytes = Array("FoldKernel-1.0.0".utf8)
        let combined = versionBytes + memorySignature
        return Keccak256().hash(combined)
    }
}
