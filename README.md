# OKLCHColor

Write SwiftUI and UIKit colors in OKLCH, the same space as CSS `oklch(L C H)`.

```swift
import OKLCHColor

Color(oklch: 0.55, 0.15, 262)
Color(oklch: 0.55, 0.15, 262, opacity: 0.5)
UIColor(oklch: 0.55, 0.15, 262)
```

For a color with a light and a dark value:

```swift
Color(light: Color(oklch: 0.97, 0.008, 80), dark: Color(oklch: 0.15, 0.006, 60))
UIColor(light: UIColor(oklch: 0.97, 0.008, 80), dark: UIColor(oklch: 0.15, 0.006, 60))
```

It follows the color scheme, including `.preferredColorScheme`. `NSColor` has the same initializer on macOS; watchOS has no light mode, so it doesn't.

- L: lightness 0...1, C: chroma 0...~0.37, H: hue in degrees.
- Renders in Display P3 by default (`gamut: .sRGB` is optional).
- Colors outside the target gamut are mapped with the CSS Color 4 algorithm,
  matching color.js `toGamut({ method: "css" })`: chroma drops at fixed L and H
  until clipping the rest is no longer noticeable. Browsers currently clip
  instead, so very saturated colors can differ from what Chrome shows.

## The OKLCH value

`OKLCH` holds L, C, H and alpha, so you can read and mix colors in OKLCH.

```swift
let accent = OKLCH(0.55, 0.15, 262)                   // the hue wraps to 0..<360
let fromColor = OKLCH(color.resolve(in: environment)) // iOS 17 and later
let fromUIColor = OKLCH(UIColor.systemBlue)           // nil if the conversion fails
let hover = accent.mixed(with: OKLCH(1, 0, 0), by: 0.2)
hover.color()                                         // Display P3; color(in: .sRGB) is optional
```

- `mixed(with:by:)` works like CSS `color-mix(in oklch)`: the hue takes the shorter way, and `t` is not clamped.
- A grey (chroma below 0.000004) has no hue: its hue is 0, and in a mix it takes the hue of the other color.
- A mix with alpha premultiplies L and C, so a transparent color does not pull the result toward its L and C.
- A color converts through the system color management. For Display P3 colors, the result can differ from CSS by about 0.0001.

## Install

In Xcode: File › Add Package Dependencies, then enter this repository's URL.

```swift
.package(url: "https://github.com/ETSoftwareStudio/oklch-swift.git", from: "1.2.0")
```

For gradients blended in OKLCH, pair it with
[OKLCHGradient](https://github.com/fwrs/OKLCHGradient).

Math: Björn Ottosson, "A perceptual color space for image processing".

## License

MIT. See [LICENSE](LICENSE).
