# Calc

A minimal SwiftUI calculator for iOS 26 with Liquid Glass.

- Arithmetic plus scientific functions (trig, inverse trig, hyperbolic, ln/log, roots, factorial, powers, π, e) with a DEG/RAD toggle and history
- Graphing: functions, equations, inequalities, parametric, polar and piecewise graphs, named variables and functions, sliders, points of interest, tables with regression, saved graphs; plus 3D and complex-plane graphs
- Extras: unit converter, fractals, formula reference and statistics tools
- Unit converter covering 10 categories
- Settings for theme (system, light, dark), accent color, angle unit, precision, haptics and grid
- Dark mode

## Build the IPA

The IPA has to be built on macOS with Xcode 26. The GitHub Actions workflow in `.github/workflows/build-ipa.yml` does this on every push to `main` or `master`, or when you run it by hand from the Actions tab. It uploads `Calc-unsigned.ipa` as an artifact.

The IPA is unsigned. Sign and install it with your Apple ID using Sideloadly, AltStore or similar. A TestFlight or App Store build needs an Apple Developer account.

## Build locally

```sh
brew install xcodegen
xcodegen generate
open Calc.xcodeproj
```

Pick your team under Signing & Capabilities, then run on a device or simulator.
