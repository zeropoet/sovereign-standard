import CoreGraphics

public struct SVGExporter {
    public init() {}

    public func export(_ geometry: SigilGeometry) -> String {
        let points = geometry.points

        guard points.count > 1 else {
            return ""
        }

        var path = "M \(points[0].x) \(points[0].y)"

        for point in points.dropFirst() {
            path += " L \(point.x) \(point.y)"
        }
        path += " Z"

        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg"
             viewBox="0 0 1 1">
            <path d="\(path)"
                  fill="black"
                  stroke="black"
                  stroke-width="0.006"
                  stroke-linejoin="round"
                  stroke-linecap="round" />
        </svg>
        """

        return svg
    }
}
