import Foundation
import CoreGraphics
import FoldKernel

public struct SigilGenerator {

    public init() {}

    public func generate(
        events: [FoldEvent],
        canonicalDistance: CanonicalDistance,
        convergenceEvaluator: ConvergenceEvaluator
    ) -> SigilGeometry {
        guard events.count > 1 else {
            return SigilGeometry(points: [])
        }

        let distances = events.compactMap { event -> Int? in
            guard case .permutationCommit(let permutation) = event else {
                return nil
            }

            return canonicalDistance.distance(from: permutation)
        }
        let maxDistance = distances.max() ?? 0
        let normalizedMaxDistance = CGFloat(max(maxDistance, 1))
        let diagonalStart = CGPoint(x: 0.12, y: 0.88)
        let diagonalEnd = CGPoint(x: 0.88, y: 0.12)
        let diagonalVector = CGPoint(
            x: diagonalEnd.x - diagonalStart.x,
            y: diagonalEnd.y - diagonalStart.y
        )
        let diagonalLength = sqrt(
            (diagonalVector.x * diagonalVector.x) +
            (diagonalVector.y * diagonalVector.y)
        )
        let tangent = CGPoint(
            x: diagonalVector.x / diagonalLength,
            y: diagonalVector.y / diagonalLength
        )
        let normal = CGPoint(
            x: -tangent.y,
            y: tangent.x
        )

        var points: [CGPoint] = []
        let stepCount = max(events.count - 1, 1)
        let maxNormalOffset: CGFloat = 0.09
        let crossingAmplitude: CGFloat = 0.03
        let minimumXStep: CGFloat = 0.004

        for (index, event) in events.enumerated() {
            guard case .permutationCommit(let permutation) = event else {
                continue
            }

            let currentDistance = canonicalDistance.distance(from: permutation)
            let progress = CGFloat(index) / CGFloat(stepCount)
            let basePoint = CGPoint(
                x: diagonalStart.x + (diagonalVector.x * progress),
                y: diagonalStart.y + (diagonalVector.y * progress)
            )
            let normalizedDistance = CGFloat(currentDistance) / normalizedMaxDistance
            let taperedDistanceOffset = ((normalizedDistance * 2) - 1) * maxNormalOffset * bladeEnvelope(at: progress)
            let crossingBias = ((progress * 2) - 1) * crossingAmplitude
            let spineOffset = taperedDistanceOffset + crossingBias
            let point = CGPoint(
                x: basePoint.x + (normal.x * spineOffset),
                y: basePoint.y + (normal.y * spineOffset)
            )

            if let previousPoint = points.last {
                points.append(
                    CGPoint(
                        x: max(point.x, previousPoint.x + minimumXStep),
                        y: point.y
                    )
                )
            } else {
                points.append(point)
            }
        }

        return SigilGeometry(points: points)
    }

    private func bladeEnvelope(at progress: CGFloat) -> CGFloat {
        let towardTip = max(0.18, 1 - pow(progress, 1.8))
        let nearBase = 0.8 + ((1 - progress) * 0.2)
        return towardTip * nearBase
    }
}
