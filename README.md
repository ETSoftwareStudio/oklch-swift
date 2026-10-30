# OKLCHColor

Write SwiftUI and UIKit colors in OKLCH, the same space as CSS `oklch(L C H)`.

```swift
import OKLCHColor

Color(oklch: 0.55, 0.15, 262)
Color(oklch: 0.55, 0.15, 262, opacity: 0.5)
UIColor(oklch: 0.55, 0.15, 262)
```

- L: lightness 0...1, C: chroma 0...~0.37, H: hue in degrees.
- Renders in Display P3 by default (`gamut: .sRGB` is optional).
- Colors outside the target gamut are mapped by reducing chroma at fixed L and H,
  as CSS Color 4 does, so hue and lightness never shift.

## Install

In Xcode: File › Add Package Dependencies, then enter this repository's URL.

```swift
.package(url: "https://github.com/ETSoftwareStudio/oklch-color.git", from: "1.0.0")
```

For gradients blended in OKLCH, pair it with
[OKLCHGradient](https://github.com/fwrs/OKLCHGradient).

Math: Björn Ottosson, "A perceptual color space for image processing".
