# Exochronometer iOS

Native SwiftUI rewrite of [exochronometer](https://github.com/alchemicAV/exochronometer) — a geometric time visualization, plus home-screen and lock-screen widgets.

## Project status

Early scaffold.

- App: vertical stack of time circles (year / moon / quarter-moon / day / hour / minute) with smooth animation.
- Widget bundle: configurable large home-screen widget and a circular lock-screen widget. User picks the timeframe per widget instance; add it twice for two different views.
- **Not ported yet:** geometry overlays (inscribed polygons / star polygons), ghost trails, journal, timeline view.

## Requirements

- Xcode 26+ on macOS
- iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for regenerating the project file (`brew install xcodegen`)

## Build

```bash
xcodegen generate
open Exochronometer.xcodeproj
```

Pick the **Exochronometer** scheme, an iPhone simulator, and ⌘R.

## Running on a physical iPhone (no paid Developer Program)

1. Plug in your device, trust this Mac.
2. Xcode → Signing & Capabilities → set your free Apple ID as the team. Xcode will auto-generate a personal provisioning profile.
3. Build & run. The app will be installed but the signing profile expires in 7 days.
4. To auto-re-sign over Wi-Fi without manually rebuilding, use [AltStore](https://altstore.io) or [SideStore](https://sidestore.io).

## Widget configuration

Long-press a widget → **Edit Widget** → pick a timeframe (Year, Moon, Quarter Moon, Day, Hour). Minute is excluded because widget refresh cadence (~minutes) makes a continuously-spinning minute hand useless. Add the widget more than once with different timeframes for multiple views on the home screen.

## Project layout

- `ExochronometerCore/` — Pure-Swift time, moon, and geometry math. Shared framework linked by both app and widget.
- `Exochronometer/` — SwiftUI app target.
- `ExochronometerWidget/` — WidgetKit extension. Targets `.systemLarge` and `.accessoryCircular`.
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec. The `.xcodeproj` is generated from this. Re-run `xcodegen generate` after editing.

## App Group

App and widget share `group.com.alchemicav.exochronometer` so journal data (once ported) is readable by the widget.

## Roadmap

- [ ] Port geometry overlay rendering (inscribed polygons / star polygons)
- [ ] Port ghost trails
- [ ] Port journal (SwiftData, App Group shared store)
- [ ] Port timeline view
- [ ] App icon + widget gallery previews
- [ ] Live Activity for in-progress timeframes?
