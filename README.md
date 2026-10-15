# Calc

A minimal SwiftUI calculator for iOS 26 with Liquid Glass.

- Arithmetic plus scientific functions (trig, inverse trig, hyperbolic, ln/log, roots, factorial, powers, π, e) with a DEG/RAD toggle and history
- Graphing calculator with up to four functions, pan and pinch-zoom
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

## Lexi

A minimal dictionary and thesaurus in `Lexi/`, built for deaf and hard-of-hearing users: pronunciations are written out (IPA plus a plain-language sound guide), with no audio.

- Definitions, synonyms, antonyms and related words
- History and favorites, saved on device
- Liquid Glass design, dark mode, custom accent color

The `Build Lexi IPA` workflow produces `Lexi-unsigned.ipa`. Definitions come from dictionaryapi.dev and related words from Datamuse, so it needs a network connection.
