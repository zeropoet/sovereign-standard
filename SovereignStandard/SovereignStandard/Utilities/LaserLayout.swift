import Foundation

enum LaserLayout {
    static func frontSVG(unit: UnitOutput) -> String {
        let displayHash = String(unit.hash.prefix(9))

        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000" width="1000" height="1000">
          <text x="180" y="220" text-anchor="start" fill="black" font-family="'IBM Plex Mono', 'SFMono-Regular', Menlo, monospace" font-size="32" letter-spacing="1.4">SOVEREIGN STANDARD - \(unit.unitID)</text>
          <text x="180" y="272" text-anchor="start" fill="black" font-family="'IBM Plex Mono', 'SFMono-Regular', Menlo, monospace" font-size="32" letter-spacing="1.4">\(displayHash)</text>
        </svg>
        """
    }

    static func backSVG(unit: UnitOutput, qrSVG: String) -> String {
        let sigil = embedded(svg: unit.sigilSVG, x: 110, y: 100, width: 780, height: 780)
        let qr = embedded(svg: qrSVG, x: 690, y: 690, width: 180, height: 180)

        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000" width="1000" height="1000">
          \(sigil)
          \(qr)
        </svg>
        """
    }

    private static func embedded(svg: String, x: Int, y: Int, width: Int, height: Int) -> String {
        let viewBox = attribute(named: "viewBox", in: svg) ?? "0 0 \(width) \(height)"
        let body = innerSVG(of: svg)
        let transform = transformForEmbedded(viewBox: viewBox, x: x, y: y, width: width, height: height)

        return """
        <g transform="\(transform)">
        \(body)
        </g>
        """
    }

    private static func transformForEmbedded(viewBox: String, x: Int, y: Int, width: Int, height: Int) -> String {
        let components = viewBox
            .split(separator: " ")
            .compactMap { Double($0) }

        guard components.count == 4, components[2] != 0, components[3] != 0 else {
            return "translate(\(x) \(y))"
        }

        let minX = components[0]
        let minY = components[1]
        let viewWidth = components[2]
        let viewHeight = components[3]
        let scaleX = Double(width) / viewWidth
        let scaleY = Double(height) / viewHeight

        return "translate(\(x) \(y)) scale(\(scaleX) \(scaleY)) translate(\(-minX) \(-minY))"
    }

    private static func attribute(named name: String, in svg: String) -> String? {
        guard let range = svg.range(of: #"\#(name)="[^"]+""#, options: .regularExpression) else {
            return nil
        }

        let token = String(svg[range])
        guard let firstQuote = token.firstIndex(of: "\""),
              let lastQuote = token.lastIndex(of: "\""),
              firstQuote < lastQuote else {
            return nil
        }

        return String(token[token.index(after: firstQuote)..<lastQuote])
    }

    private static func innerSVG(of svg: String) -> String {
        guard let open = svg.range(of: ">"),
              let close = svg.range(of: "</svg>", options: .backwards),
              open.upperBound <= close.lowerBound else {
            return svg
        }

        return String(svg[open.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
