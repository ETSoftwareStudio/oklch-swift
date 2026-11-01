import SwiftUI
import XCTest
@testable import OKLCHColor

final class OKLCHTests: XCTestCase {
    func testWhiteAndBlackMapToGamutEdges() {
        assertRGB(OKLCH.rgb(1, 0, 0, in: .sRGB), equals: (1, 1, 1))
        assertRGB(OKLCH.rgb(0, 0, 0, in: .sRGB), equals: (0, 0, 0))
        assertRGB(OKLCH.rgb(1, 0, 0, in: .displayP3), equals: (1, 1, 1))
    }

    func testKnownColorsMatchSRGB() {
        // Reference values from CSS Color 4 (oklch() -> srgb).
        assertRGB(OKLCH.rgb(0.6279554, 0.2576833, 29.2339, in: .sRGB), equals: (1, 0, 0))
        assertRGB(OKLCH.rgb(0.8664396, 0.2948272, 142.4953, in: .sRGB), equals: (0, 1, 0))
        assertRGB(OKLCH.rgb(0.4520137, 0.3132144, 264.0520, in: .sRGB), equals: (0, 0, 1))
    }

    func testSRGBRedFitsInsideDisplayP3() {
        let rgb = OKLCH.rgb(0.6279554, 0.2576833, 29.2339, in: .displayP3)

        XCTAssertLessThan(rgb.red, 1)
        XCTAssertGreaterThan(rgb.green, 0)
    }

    func testOutOfGamutChromaStaysInsideGamut() {
        for gamut in [OKLCHGamut.sRGB, .displayP3] {
            let rgb = OKLCH.rgb(0.7, 0.4, 150, in: gamut)

            for channel in [rgb.red, rgb.green, rgb.blue] {
                XCTAssertGreaterThanOrEqual(channel, 0)
                XCTAssertLessThanOrEqual(channel, 1)
            }
        }
    }

    func testGamutMappingKeepsHue() {
        let mapped = OKLCH.rgb(0.7, 0.4, 150, in: .sRGB)
        let reduced = OKLCH.rgb(0.7, 0.1, 150, in: .sRGB)

        // Both should be green-dominant: hue held while chroma drops.
        XCTAssertGreaterThan(mapped.green, mapped.red)
        XCTAssertGreaterThan(mapped.green, mapped.blue)
        XCTAssertGreaterThan(reduced.green, reduced.red)
    }

    func testLightDarkColorFollowsTheColorScheme() throws {
        guard #available(iOS 17, macOS 14, tvOS 17, visionOS 1, *) else { throw XCTSkip("Color.resolve needs iOS 17") }
        let color = Color(light: Color(oklch: 1, 0, 0), dark: Color(oklch: 0, 0, 0))
        var environment = EnvironmentValues()

        environment.colorScheme = .light
        XCTAssertEqual(color.resolve(in: environment).red, 1, accuracy: 0.01)
        environment.colorScheme = .dark
        XCTAssertEqual(color.resolve(in: environment).red, 0, accuracy: 0.01)
    }

    private func assertRGB(
        _ rgb: (red: Double, green: Double, blue: Double),
        equals expected: (Double, Double, Double),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let tolerance = 1.0 / 255
        XCTAssertEqual(rgb.red, expected.0, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(rgb.green, expected.1, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(rgb.blue, expected.2, accuracy: tolerance, file: file, line: line)
    }
}
