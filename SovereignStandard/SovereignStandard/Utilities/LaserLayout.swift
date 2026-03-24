import Foundation

enum LaserLayout {
    static func frontSVG(unit: UnitOutput) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000" width="1000" height="1000">
          <rect width="100%" height="100%" fill="white"/>
          <text x="500" y="220" text-anchor="middle" font-family="Times New Roman, serif" font-size="54" letter-spacing="6">SOVEREIGN STANDARD</text>
          <text x="500" y="520" text-anchor="middle" font-family="Courier New, monospace" font-size="72">UNIT \(unit.unitID)</text>
          <text x="500" y="620" text-anchor="middle" font-family="Courier New, monospace" font-size="24">\(unit.hash)</text>
        </svg>
        """
    }

    static func backSVG(unit: UnitOutput, qrSVG: String) -> String {
        let sigil = embedded(svg: unit.sigilSVG, x: 110, y: 100, width: 780, height: 780)
        let qr = embedded(svg: qrSVG, x: 690, y: 690, width: 180, height: 180)

        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000" width="1000" height="1000">
          <rect width="100%" height="100%" fill="white"/>
          \(sigil)
          \(qr)
        </svg>
        """
    }

    private static func embedded(svg: String, x: Int, y: Int, width: Int, height: Int) -> String {
        svg.replacingOccurrences(
            of: "<svg ",
            with: #"<svg x="\#(x)" y="\#(y)" width="\#(width)" height="\#(height)" "#
        )
    }
}
