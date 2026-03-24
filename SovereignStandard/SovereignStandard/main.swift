import Foundation

let app = SovereignStandardApp()

do {
    try app.run(arguments: CommandLine.arguments)
} catch {
    FileHandle.standardError.write(Data("SovereignStandard failed: \(error)\n".utf8))
    exit(1)
}
