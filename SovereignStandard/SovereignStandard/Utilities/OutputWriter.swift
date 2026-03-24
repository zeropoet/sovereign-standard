import Foundation

struct OutputWriter {
    private let qrCode = QRCode()

    func write(unit: UnitOutput, outputRoot: URL) throws {
        let unitDirectory = outputRoot.appendingPathComponent(String(unit.unitID), isDirectory: true)

        try FileManager.default.createDirectory(
            at: unitDirectory,
            withIntermediateDirectories: true
        )

        let qrSVG = try qrCode.exportSVG(
            url: "https://control.sovereignstandard.co/unit/\(unit.unitID)"
        )
        let frontSVG = LaserLayout.frontSVG(unit: unit)
        let backSVG = LaserLayout.backSVG(unit: unit, qrSVG: qrSVG)

        try unit.sigilSVG.write(
            to: unitDirectory.appendingPathComponent("sigil.svg"),
            atomically: true,
            encoding: .utf8
        )

        try qrSVG.write(
            to: unitDirectory.appendingPathComponent("qr.svg"),
            atomically: true,
            encoding: .utf8
        )

        try frontSVG.write(
            to: unitDirectory.appendingPathComponent("front.svg"),
            atomically: true,
            encoding: .utf8
        )

        try backSVG.write(
            to: unitDirectory.appendingPathComponent("back.svg"),
            atomically: true,
            encoding: .utf8
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(unit)
        try data.write(to: unitDirectory.appendingPathComponent("data.json"))
    }
}
