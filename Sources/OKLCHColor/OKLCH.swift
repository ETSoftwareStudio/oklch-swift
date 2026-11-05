// OKLCH.swift
// Write colors in OKLCH, the same space as CSS `oklch(L C H)`.
//
//   Color(oklch: 0.55, 0.15, 262)
//   Color(oklch: 0.55, 0.15, 262, opacity: 0.5)
//   UIColor(oklch: 0.55, 0.15, 262)
//   Color(light: Color(oklch: 0.97, 0.01, 80), dark: Color(oklch: 0.15, 0.01, 60))
//
// L: lightness 0...1, C: chroma 0...~0.37, H: hue in degrees.
// Renders in Display P3 by default (sRGB optional). Colors outside the
// target gamut are mapped with the CSS Color 4 algorithm: chroma drops at
// fixed L and H until clipping is no longer noticeable.
// Math: Björn Ottosson, "A perceptual color space for image processing".

import Foundation

public enum OKLCHGamut {
    case displayP3
    case sRGB
}

public enum OKLCH {
    /// Converts OKLCH to gamma-encoded RGB components (0...1) in the given gamut.
    public static func rgb(
        _ l: Double, _ c: Double, _ h: Double, in gamut: OKLCHGamut = .displayP3
    ) -> (red: Double, green: Double, blue: Double) {
        let linear = mapToGamut(min(max(l, 0), 1), max(c, 0), h, gamut)
        return (encode(linear.0), encode(linear.1), encode(linear.2))
    }

    private typealias Triple = (Double, Double, Double)

    // CSS Color 4 gamut mapping (section 13.2.2): bisect chroma at fixed L and H,
    // stopping once clipping the color changes it by less than a just-noticeable
    // difference in OKLab, then return the clipped color.
    private static func mapToGamut(_ l: Double, _ c: Double, _ h: Double, _ gamut: OKLCHGamut) -> Triple {
        if l >= 1 { return (1, 1, 1) }
        if l <= 0 { return (0, 0, 0) }
        let origin = linearRGB(l, c, h, gamut)
        if inGamut(origin) { return origin }

        let jnd = 0.02, epsilon = 0.0001
        var clipped = clip(origin)
        if deltaEOK(clipped, oklab(l, c, h), gamut) < jnd { return clipped }

        var low = 0.0, high = c, lowInGamut = true
        while high - low > epsilon {
            let chroma = (low + high) / 2
            let current = linearRGB(l, chroma, h, gamut)
            if lowInGamut && inGamut(current) {
                low = chroma
                continue
            }
            clipped = clip(current)
            let e = deltaEOK(clipped, oklab(l, chroma, h), gamut)
            if e < jnd {
                if jnd - e < epsilon { return clipped }
                lowInGamut = false
                low = chroma
            } else {
                high = chroma
            }
        }
        return clipped
    }

    private static func oklab(_ l: Double, _ c: Double, _ h: Double) -> Triple {
        let hr = h * .pi / 180
        return (l, c * cos(hr), c * sin(hr))
    }

    private static func linearRGB(_ l: Double, _ c: Double, _ h: Double, _ gamut: OKLCHGamut) -> Triple {
        let (l, a, b) = oklab(l, c, h)

        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let lc = l_ * l_ * l_, mc = m_ * m_ * m_, sc = s_ * s_ * s_

        let r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        switch gamut {
        case .sRGB:
            return (r, g, bl)
        case .displayP3:
            // Linear sRGB -> linear Display P3.
            return (
                0.8224621209 * r + 0.1775378791 * g,
                0.0331941989 * r + 0.9668058011 * g,
                0.0170826307 * r + 0.0723974407 * g + 0.9105199286 * bl
            )
        }
    }

    // Linear RGB in the given gamut -> OKLab (Ottosson's forward matrices).
    private static func oklab(linear v: Triple, _ gamut: OKLCHGamut) -> Triple {
        var (r, g, b) = v
        if gamut == .displayP3 {
            // Linear Display P3 -> linear sRGB.
            (r, g, b) = (
                1.2249401763 * v.0 - 0.2249401763 * v.1,
                -0.0420569547 * v.0 + 1.0420569547 * v.1,
                -0.0196375546 * v.0 - 0.0786360456 * v.1 + 1.0982736002 * v.2
            )
        }
        let l_ = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m_ = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s_ = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        )
    }

    private static func deltaEOK(_ linear: Triple, _ lab: Triple, _ gamut: OKLCHGamut) -> Double {
        let other = oklab(linear: linear, gamut)
        let dl = other.0 - lab.0, da = other.1 - lab.1, db = other.2 - lab.2
        return (dl * dl + da * da + db * db).squareRoot()
    }

    private static func clip(_ v: Triple) -> Triple {
        (min(max(v.0, 0), 1), min(max(v.1, 0), 1), min(max(v.2, 0), 1))
    }

    private static func inGamut(_ v: Triple) -> Bool {
        let e = 1e-6
        return v.0 >= -e && v.0 <= 1 + e && v.1 >= -e && v.1 <= 1 + e && v.2 >= -e && v.2 <= 1 + e
    }

    // sRGB and Display P3 share this transfer function.
    private static func encode(_ v: Double) -> Double {
        let v = min(max(v, 0), 1)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }
}

#if canImport(SwiftUI)
import SwiftUI

public extension Color {
    init(oklch l: Double, _ c: Double, _ h: Double, opacity: Double = 1, gamut: OKLCHGamut = .displayP3) {
        let rgb = OKLCH.rgb(l, c, h, in: gamut)
        self.init(gamut == .displayP3 ? .displayP3 : .sRGB,
                  red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: opacity)
    }
}
#endif

#if canImport(UIKit)
import UIKit

public extension UIColor {
    convenience init(oklch l: Double, _ c: Double, _ h: Double, alpha: CGFloat = 1, gamut: OKLCHGamut = .displayP3) {
        let rgb = OKLCH.rgb(l, c, h, in: gamut)
        if gamut == .displayP3 {
            self.init(displayP3Red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
        } else {
            self.init(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
        }
    }
}
#endif

// MARK: - Light and dark

#if canImport(UIKit) && !os(watchOS)
public extension UIColor {
    /// A color that follows the interface style: `dark` in dark mode, `light` otherwise.
    convenience init(light: UIColor, dark: UIColor) {
        self.init { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

#if canImport(SwiftUI)
public extension Color {
    /// A color that follows the color scheme: `dark` in dark mode, `light` otherwise.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor(light: UIColor(light), dark: UIColor(dark)))
    }
}
#endif

#elseif canImport(AppKit)
import AppKit

public extension NSColor {
    /// A color that follows the appearance: `dark` in dark mode, `light` otherwise.
    convenience init(light: NSColor, dark: NSColor) {
        self.init(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}

#if canImport(SwiftUI)
public extension Color {
    /// A color that follows the color scheme: `dark` in dark mode, `light` otherwise.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(light: NSColor(light), dark: NSColor(dark)))
    }
}
#endif
#endif
