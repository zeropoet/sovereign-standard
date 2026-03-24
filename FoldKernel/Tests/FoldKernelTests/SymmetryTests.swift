import XCTest
@testable import FoldKernel

final class SymmetryTests: XCTestCase {
    func testCanonicalSquareS0ExactEquality() {
        let expected: [UInt8] = [
            13, 3, 2, 16,
            8, 10, 11, 5,
            12, 6, 7, 9,
            1, 15, 14, 4
        ]
        XCTAssertEqual(CanonicalSquare.S0.values, expected)
    }

    func testRotate90AppliedFourTimesEqualsIdentity() {
        let base = CanonicalSquare.S0
        let once = SymmetryTransform.rotate90.apply(to: base)
        let twice = SymmetryTransform.rotate90.apply(to: once)
        let thrice = SymmetryTransform.rotate90.apply(to: twice)
        let fourTimes = SymmetryTransform.rotate90.apply(to: thrice)

        XCTAssertEqual(fourTimes.values, base.values)
    }

    func testRotate180AppliedTwiceEqualsIdentity() {
        let base = CanonicalSquare.S0
        let once = SymmetryTransform.rotate180.apply(to: base)
        let twice = SymmetryTransform.rotate180.apply(to: once)

        XCTAssertEqual(twice.values, base.values)
    }

    func testRotate270AppliedFourTimesEqualsIdentity() {
        let base = CanonicalSquare.S0
        let once = SymmetryTransform.rotate270.apply(to: base)
        let twice = SymmetryTransform.rotate270.apply(to: once)
        let thrice = SymmetryTransform.rotate270.apply(to: twice)
        let fourTimes = SymmetryTransform.rotate270.apply(to: thrice)

        XCTAssertEqual(fourTimes.values, base.values)
    }

    func testEachReflectionAppliedTwiceEqualsIdentity() {
        let base = CanonicalSquare.S0
        let reflections: [SymmetryTransform] = [
            .reflectHorizontal,
            .reflectVertical,
            .reflectMainDiagonal,
            .reflectAntiDiagonal
        ]

        for reflection in reflections {
            let once = reflection.apply(to: base)
            let twice = reflection.apply(to: once)
            XCTAssertEqual(twice.values, base.values)
        }
    }

    func testOrbitSizeIsExactlyEight() {
        let base = CanonicalSquare.S0
        let transformedPermutations = SymmetryTransform.allCases.map { $0.apply(to: base).values }

        XCTAssertEqual(Set(transformedPermutations).count, 8)
    }
}
