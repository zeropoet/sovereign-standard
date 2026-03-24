import XCTest
@testable import SovereignStandard

final class SovereignStandardTests: XCTestCase {
    func testGenerateUnitIsDeterministic() {
        let engine = SovereignEngine()

        let first = engine.generateUnit(unitID: 136)
        let second = engine.generateUnit(unitID: 136)

        XCTAssertEqual(first.permutation.values, second.permutation.values)
        XCTAssertEqual(first.memory, second.memory)
        XCTAssertEqual(first.hash, second.hash)
        XCTAssertEqual(first.sigilSVG, second.sigilSVG)
        XCTAssertEqual(first.events.count, second.events.count)
    }
}
