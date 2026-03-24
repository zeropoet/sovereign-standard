import Foundation

enum LaserLayout {
    static func frontSVG(unit: UnitOutput) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000" width="1000" height="1000">
          <rect width="100%" height="100%" fill="white"/>
          <text x="500" y="220" text-anchor="middle" font-family="Times New Roman, serif" font-size="46" letter-spacing="4">SOVEREIGN STANDARD - \(unit.unitID)</text>
          <text x="500" y="620" text-anchor="middle" font-family="Courier New, monospace" font-size="24">\(unit.hash)</text>
        </svg>
        """
    }

    static func backSVG(unit: UnitOutput, qrSVG: String) -> String {
        _ = unit
        _ = qrSVG

        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000" width="1000" height="1000">
          <rect width="100%" height="100%" fill="white"/>
          <image href="sigil.svg" x="110" y="100" width="780" height="780" preserveAspectRatio="xMidYMid meet"/>
          <image href="qr.svg" x="690" y="690" width="180" height="180" preserveAspectRatio="xMidYMid meet"/>
        </svg>
        """
    }
}
