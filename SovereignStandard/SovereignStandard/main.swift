import Foundation

let app = SovereignStandardApp()

do {
    try app.run()
} catch {
    FileHandle.standardError.write(Data("SovereignStandard failed: \(error)\n".utf8))
    exit(1)
}
