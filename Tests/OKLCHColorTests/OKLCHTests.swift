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

    func testOutOfGamutColorsMatchCSSColor4() {
        // Reference: color.js 0.5.2 (by the CSS Color 4 editors), toGamut({ method: "css" }).
        let cases: [(l: Double, c: Double, h: Double, srgb: (Double, Double, Double), p3: (Double, Double, Double))] = [
            (0.434, 0.341, 260.9, (0, 0, 0.970663), (0, 0, 0.931551)),
            (0.323, 0.378, 260.4, (0, 0, 0.666005), (0, 0, 0.638161)),
            (0.938, 0.255, 98.4, (1, 0.919207, 0), (1, 0.921756, 0.150577)),
            (0.7, 0.4, 150, (0, 0.760678, 0.280818), (0, 0.782484, 0.194446)),
            (0.65, 0.3, 30, (1, 0.075194, 0), (1, 0.016388, 0)),
            (0.5, 0.35, 320, (0.621752, 0, 0.736444), (0.578124, 0, 0.732095)),
            (0.9, 0.2, 200, (0, 0.996949, 1), (0.249846, 0.992796, 1)),
            (0.25, 0.3, 140, (0, 0.172754, 0), (0.012417, 0.173921, 0)),
            (0.8, 0.37, 60, (1, 0.626934, 0.21197), (1, 0.61329, 0.09717)),
        ]
        for (l, c, h, srgb, p3) in cases {
            assertRGB(OKLCH.rgb(l, c, h, in: .sRGB), equals: srgb)
            assertRGB(OKLCH.rgb(l, c, h, in: .displayP3), equals: p3)
        }
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
