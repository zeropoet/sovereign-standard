import CoreGraphics
import FoldKernel

public struct SigilGenerator {
    private let scaleX: CGFloat = 1.0 / 16.0

    public init() {}

    public func generate(
        events: [FoldEvent],
        canonicalDistance: CanonicalDistance,
        convergenceEvaluator: ConvergenceEvaluator
    ) -> SigilGeometry {
        guard events.count > 1 else {
            return SigilGeometry(points: [])
        }

        var points: [CGPoint] = []
        var previousSum = false
        var previousAdj = false
        var previousOrbit = false
        var previousDistance: Int?
        var previousX: CGFloat?
        var previousY: CGFloat?
        let scaleY = 1.0 / CGFloat(max(events.count, 1))
        let dwellSteps = 2
        let inflect: CGFloat = 1.4

        for (index, event) in events.enumerated() {
            switch event {
            case .permutationCommit(let permutation):
                let currentDistance = canonicalDistance.distance(from: permutation)
                let improving = previousDistance == nil
                    ? true
                    : currentDistance < previousDistance!
                let state = convergenceEvaluator.evaluate(permutation)
                let sumNow = state.sumSatisfied
                let adjNow = state.adjacencySatisfied
                let orbitNow = currentDistance == 0

                let sumActivated = !previousSum && sumNow
                let adjActivated = !previousAdj && adjNow
                let orbitActivated = !previousOrbit && orbitNow

                var x = CGFloat(currentDistance)
                var y = CGFloat(index)

                if sumActivated {
                    y += inflect
                }

                if adjActivated {
                    x += inflect
                }

                if orbitActivated {
                    y -= inflect
                }

                if !improving,
                    let previousX,
                    let previousY {
                    for step in 1...dwellSteps {
                        let t = CGFloat(step) / CGFloat(dwellSteps + 1)
                        let intermediateX = previousX + ((x - previousX) * t)
                        let intermediateY = previousY + ((y - previousY) * t)

                        points.append(
                            CGPoint(
                                x: intermediateX * scaleX,
                                y: intermediateY * scaleY
                            )
                        )
                    }
                }

                points.append(
                    CGPoint(
                        x: x * scaleX,
                        y: y * scaleY
                    )
                )

                previousDistance = currentDistance
                previousX = x
                previousY = y
                previousSum = sumNow
                previousAdj = adjNow
                previousOrbit = orbitNow
            default:
                continue
            }
        }

        return SigilGeometry(points: points)
    }
}
