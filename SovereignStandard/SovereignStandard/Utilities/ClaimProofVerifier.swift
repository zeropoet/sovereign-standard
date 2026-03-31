import CryptoKit
import Foundation
import Vision

struct ClaimProofVerifier {
    func verify(imageAt url: URL, expectedSHA256: String, expectedUnitURL: String) throws {
        let imageData = try Data(contentsOf: url)
        let actualSHA256 = Self.sha256(for: imageData)

        guard actualSHA256 == expectedSHA256.lowercased() else {
            throw ClaimProofVerificationError.imageHashMismatch
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(url: url)
        try handler.perform([request])

        let payloads = request.results?
            .compactMap(\.payloadStringValue)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []

        guard payloads.contains(expectedUnitURL) else {
            throw ClaimProofVerificationError.qrPayloadMismatch
        }
    }

    static func sha256(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum ClaimProofVerificationError: LocalizedError {
    case imageHashMismatch
    case qrPayloadMismatch

    var errorDescription: String? {
        switch self {
        case .imageHashMismatch:
            return "Proof image hash verification failed."
        case .qrPayloadMismatch:
            return "Proof image QR verification failed."
        }
    }
}
