// OKLCH.swift
// Write colors in OKLCH, the same space as CSS `oklch(L C H)`.
//
//   Color(oklch: 0.55, 0.15, 262)
//   Color(oklch: 0.55, 0.15, 262, opacity: 0.5)
//   UIColor(oklch: 0.55, 0.15, 262)
//
// L: lightness 0...1, C: chroma 0...~0.37, H: hue in degrees.
// Renders in Display P3 by default (sRGB optional). Colors outside the
// target gamut are mapped by reducing chroma at fixed L and H, the same
// approach CSS Color 4 uses, so hue and lightness never shift.
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
        let l = min(max(l, 0), 1)
        let c = max(c, 0)

        var linear = linearRGB(l, c, h, gamut)
        if !inGamut(linear) {
            // Bisect chroma down until the color fits.
            var low = 0.0, high = c
            for _ in 0..<24 {
                let mid = (low + high) / 2
                if inGamut(linearRGB(l, mid, h, gamut)) { low = mid } else { high = mid }
            }
            linear = linearRGB(l, low, h, gamut)
        }
        return (encode(linear.0), encode(linear.1), encode(linear.2))
    }

    private static func linearRGB(
        _ l: Double, _ c: Double, _ h: Double, _ gamut: OKLCHGamut
    ) -> (Double, Double, Double) {
        let hr = h * .pi / 180
        let a = c * cos(hr), b = c * sin(hr)

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

    private static func inGamut(_ v: (Double, Double, Double)) -> Bool {
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
