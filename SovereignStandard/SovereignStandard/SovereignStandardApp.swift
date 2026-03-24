import Foundation

struct SovereignStandardApp {
    let engine = SovereignEngine()
    let outputWriter = OutputWriter()

    func run(unitRange: Range<Int> = 136..<150) throws {
        let outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("output", isDirectory: true)

        for unitID in unitRange {
            let unit = engine.generateUnit(unitID: unitID)
            try outputWriter.write(unit: unit, outputRoot: outputRoot)
        }
    }
}
