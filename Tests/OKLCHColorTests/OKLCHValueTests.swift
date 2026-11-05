import SwiftUI
import XCTest
@testable import OKLCHColor
#if canImport(AppKit)
import AppKit
#endif

// Expected values come from the shared reference (ref.py) that oklch-android also uses.
final class OKLCHValueTests: XCTestCase {
    private typealias Vector = (rgb: (Double, Double, Double), oklch: (Double, Double, Double, Double))

    private let srgbVectors: [Vector] = [
        ((1, 1, 1), (1.000000, 0.000000, 0.000000, 1)),
        ((0, 0, 0), (0.000000, 0.000000, 0.000000, 1)),
        ((0.5, 0.5, 0.5), (0.598181, 0.000000, 0.000000, 1)),
        ((1, 0, 0), (0.627955, 0.257683, 29.233885, 1)),
        ((0, 1, 0), (0.866440, 0.294827, 142.495339, 1)),
        ((0, 0, 1), (0.452014, 0.313214, 264.052021, 1)),
        ((0.8, 0.4, 0.2), (0.622774, 0.144560, 45.069378, 1)),
    ]

    private let displayP3Vectors: [Vector] = [
        ((1, 0, 0), (0.648574, 0.299485, 28.958137, 1)),
        ((0, 1, 0), (0.848829, 0.368528, 145.644950, 1)),
        ((0.8, 0.4, 0.2), (0.632404, 0.171699, 43.230358, 1)),
    ]

    // MARK: - From a color

    func testLinearSRGBMatchesReference() {
        for (rgb, expected) in srgbVectors {
            let color = OKLCH(linearRed: linear(rgb.0), green: linear(rgb.1), blue: linear(rgb.2))
            assertOKLCH(color, equals: expected, accuracy: 1e-5)
        }
    }

    func testLinearDisplayP3MatchesReference() {
        for (rgb, expected) in displayP3Vectors {
            let (r, g, b) = (linear(rgb.0), linear(rgb.1), linear(rgb.2))
            // Linear Display P3 -> linear sRGB, the CSS Color 4 matrix that ref.py uses.
            let color = OKLCH(
                linearRed: 1.2249401763 * r - 0.2249401763 * g,
                green: -0.0420569547 * r + 1.0420569547 * g,
                blue: -0.0196375546 * r - 0.0786360456 * g + 1.0982736002 * b
            )
            assertOKLCH(color, equals: expected, accuracy: 1e-5)
        }
    }

    // Apple converts Display P3 to sRGB with its own ICC matrix in Float precision. It differs
    // from the CSS matrix by about 3e-5 per entry, so these paths use a wider tolerance.
    private let platformP3Accuracy = 1e-4, platformP3HueAccuracy = 0.05

    func testResolvedColorMatchesReference() throws {
        guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) else {
            throw XCTSkip("Color.Resolved needs iOS 17")
        }
        let environment = EnvironmentValues()
        for (rgb, expected) in srgbVectors {
            let resolved = Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2).resolve(in: environment)
            assertOKLCH(OKLCH(resolved), equals: expected, accuracy: 1e-5)
        }
        for (rgb, expected) in displayP3Vectors {
            let resolved = Color(.displayP3, red: rgb.0, green: rgb.1, blue: rgb.2).resolve(in: environment)
            assertOKLCH(OKLCH(resolved), equals: expected, accuracy: platformP3Accuracy, hueAccuracy: platformP3HueAccuracy)
        }
    }

    #if canImport(AppKit)
    func testNSColorMatchesReference() throws {
        for (rgb, expected) in srgbVectors {
            let color = try XCTUnwrap(OKLCH(NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)))
            assertOKLCH(color, equals: expected, accuracy: 1e-5)
        }
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        for (rgb, expected) in displayP3Vectors {
            let cgColor = try XCTUnwrap(CGColor(colorSpace: space, components: [rgb.0, rgb.1, rgb.2, 1]))
            let color = try XCTUnwrap(OKLCH(try XCTUnwrap(NSColor(cgColor: cgColor))))
            assertOKLCH(color, equals: expected, accuracy: platformP3Accuracy, hueAccuracy: platformP3HueAccuracy)
        }
    }

    func testNSColorKeepsAlpha() throws {
        let color = try XCTUnwrap(OKLCH(NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 0.25)))

        XCTAssertEqual(color.alpha, 0.25, accuracy: 1e-6)
    }
    #endif

    // MARK: - Hue

    func testInitWrapsHue() {
        XCTAssertEqual(OKLCH(0.5, 0.1, -30).h, 330, accuracy: 1e-9)
        XCTAssertEqual(OKLCH(0.5, 0.1, 360).h, 0, accuracy: 1e-9)
        XCTAssertEqual(OKLCH(0.5, 0.1, 725).h, 5, accuracy: 1e-9)
    }

    func testInitDoesNotClampLightness() {
        XCTAssertEqual(OKLCH(1.2, 0.1, 30).l, 1.2)
    }

    // MARK: - Mix

    func testMixMatchesReference() {
        let cases: [(OKLCH, OKLCH, Double, (Double, Double, Double, Double))] = [
            // The short way through 0.
            (OKLCH(0.7, 0.1, 350), OKLCH(0.7, 0.1, 10), 0.5, (0.7, 0.1, 0, 1)),
            (OKLCH(0.7, 0.1, 10), OKLCH(0.7, 0.1, 350), 0.25, (0.7, 0.1, 5, 1)),
            // A grey side takes the hue of the other side.
            (OKLCH(1, 0, 0), OKLCH(0.5, 0.1, 60), 0.5, (0.75, 0.05, 60, 1)),
            (OKLCH(0.5, 0.1, 60), OKLCH(0, 0, 0), 0.5, (0.25, 0.05, 60, 1)),
            // Both sides grey.
            (OKLCH(1, 0, 0), OKLCH(0, 0, 0), 0.5, (0.5, 0, 0, 1)),
            // A transparent side keeps L and C.
            (OKLCH(0.6, 0.12, 30), OKLCH(0.6, 0.12, 30, alpha: 0), 0.5, (0.6, 0.12, 30, 0.5)),
            // Premultiplied: 0.248 / 0.38 = 0.652632 and 0.043 / 0.38 = 0.113158.
            (OKLCH(0.4, 0.05, 200, alpha: 0.2), OKLCH(0.8, 0.15, 100, alpha: 0.8), 0.3,
             (0.248 / 0.38, 0.043 / 0.38, 170, 0.38)),
            // t is not clamped.
            (OKLCH(0.5, 0.1, 100), OKLCH(0.7, 0.2, 140), 1.5, (0.8, 0.25, 160, 1)),
        ]
        for (a, b, t, expected) in cases {
            assertOKLCH(a.mixed(with: b, by: t), equals: expected, accuracy: 1e-9)
        }
    }

    func testMixWithBothSidesTransparentInterpolatesPlainly() {
        let mixed = OKLCH(0.2, 0.1, 10, alpha: 0).mixed(with: OKLCH(0.6, 0.3, 50, alpha: 0), by: 0.5)

        assertOKLCH(mixed, equals: (0.4, 0.2, 30, 0), accuracy: 1e-9)
    }

    func testMixEndsReturnTheInputs() {
        let a = OKLCH(0.4, 0.05, 200, alpha: 0.2), b = OKLCH(0.8, 0.15, 100, alpha: 0.8)

        assertOKLCH(a.mixed(with: b, by: 0), equals: (a.l, a.c, a.h, a.alpha), accuracy: 1e-9)
        assertOKLCH(a.mixed(with: b, by: 1), equals: (b.l, b.c, b.h, b.alpha), accuracy: 1e-9)
    }

    // MARK: - Round trip

    func testRoundTripThroughColor() throws {
        guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) else {
            throw XCTSkip("Color.Resolved needs iOS 17")
        }
        let environment = EnvironmentValues()
        let colors = [OKLCH(0.6, 0.1, 30), OKLCH(0.75, 0.08, 150), OKLCH(0.45, 0.12, 265, alpha: 0.5), OKLCH(0.9, 0.03, 90)]
        for color in colors {
            let back = OKLCH(color.color(in: .sRGB).resolve(in: environment))
            assertOKLCH(back, equals: (color.l, color.c, color.h, color.alpha), accuracy: 1e-4)
        }
    }

    func testGreyRoundTripKeepsHueZero() throws {
        guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) else {
            throw XCTSkip("Color.Resolved needs iOS 17")
        }
        let back = OKLCH(OKLCH(0.5, 0, 0).color(in: .sRGB).resolve(in: EnvironmentValues()))

        XCTAssertEqual(back.l, 0.5, accuracy: 1e-4)
        XCTAssertEqual(back.c, 0, accuracy: 1e-4)
        XCTAssertEqual(back.h, 0)
    }

    // MARK: - Helpers

    private func linear(_ v: Double) -> Double {
        let a = abs(v), s: Double = v < 0 ? -1 : 1
        return s * (a <= 0.04045 ? a / 12.92 : pow((a + 0.055) / 1.055, 2.4))
    }

    private func assertOKLCH(
        _ color: OKLCH,
        equals expected: (Double, Double, Double, Double),
        accuracy: Double,
        hueAccuracy: Double? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.l, expected.0, accuracy: accuracy, "l", file: file, line: line)
        XCTAssertEqual(color.c, expected.1, accuracy: accuracy, "c", file: file, line: line)
        // Compare hues on the circle, so 359.99999 and 0 are close.
        let dh = abs(color.h - expected.2).truncatingRemainder(dividingBy: 360)
        XCTAssertLessThanOrEqual(min(dh, 360 - dh), hueAccuracy ?? accuracy, "h \(color.h) != \(expected.2)", file: file, line: line)
        XCTAssertEqual(color.alpha, expected.3, accuracy: accuracy, "alpha", file: file, line: line)
    }
}

final class OKLCHHueSetterTests: XCTestCase {
    func testSettingHueWraps() {
        var color = OKLCH(0.5, 0.1, 10)
        color.h = -30
        XCTAssertEqual(color.h, 330, accuracy: 1e-9)
        color.h = 725
        XCTAssertEqual(color.h, 5, accuracy: 1e-9)
        color.h = 360
        XCTAssertEqual(color.h, 0)
    }
}
