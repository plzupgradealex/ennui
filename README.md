# Ennui

An ambient scene viewer for macOS. 30 procedural scenes rendered at 60 fps
via Metal GPU compositing. No data collection, no accounts, no onboarding.
You watch, breathe, tap sometimes.

An anti-doomscroll tool.

## Scenes

Every scene is drawn entirely from math and code — no images, no video files.
SwiftUI Canvas at 60 fps, flattened to a single Metal texture each frame.

| | | |
|---|---|---|
| Ancient Ruins | Art Deco LA | Aurora Borealis |
| Cel-Shaded Rainy Day | Celestial Scroll Hall | Conservatory |
| Cosmic Drift | Deep Ocean | Desert Starscape |
| Enchanted Archives | Floating Kingdom | Forgotten Library |
| Greeting the Day | Jeonju Night | Late Night Rerun |
| Lush Ruins | Medieval Village | Midnight Motel |
| Minnesota Small Town | Mystify | Night Train |
| Ontario Countryside | Paper Lantern Festival | Quiet Meal |
| Retro Garden | Retro PS1 | Salt Lamp |
| Shimizu Evening | Urban Dreamscape | Voyager Nebula |

Tapping does something gentle in each scene — a firefly, a ripple, a lantern
released with a kind message, a warmth pulse. Nothing resets, nothing startles.

Press **H** for haiku. On-device AI generates one, or the app falls back to
hand-written poems.

## Requirements

- macOS 26.0 (Tahoe) or later
- Apple Silicon (M1 / M2 / M3 / M4)
- Xcode 18 with command-line tools

## Install

```bash
git clone https://github.com/plzupgradealex/ennui.git
cd ennui
chmod +x scripts/install.sh
./scripts/install.sh
```

Builds from source and copies `Ennui.app` to `/Applications`.
First build takes about a minute.

Or build manually:

```bash
xcodebuild -project Ennui.xcodeproj -scheme Ennui -configuration Release build
```

## Controls

| Key | Action |
|---|---|
| ← → | Previous / next scene |
| Space | Show scene picker |
| H | Toggle haiku overlay |
| ? | About panel |
| S | Toggle peer sync |
| Click | Scene-specific interaction |

Hover near the bottom of the window to reveal the scene picker.

## How It Works

Each scene is a SwiftUI `TimelineView` driving a `Canvas` at 60 fps.
`.drawingGroup(opaque: false, colorMode: .extendedLinear)` composites the
Canvas into a single Metal texture on the GPU. `.allowedDynamicRange(.high)`
enables HDR on XDR displays. All animation is derived from elapsed time —
Canvas closures are pure functions of `t`.

Procedural content is generated once in `.onAppear` using a deterministic
SplitMix64 RNG, then drawn every frame from the pre-generated data.

Scenes crossfade over 2 seconds. Neighboring scenes are preloaded off-screen
when the picker is open for instant transitions.

## Privacy

Zero data collection. No analytics, no telemetry, no network calls except
optional local-network peer sync (MultipeerConnectivity, encrypted). The
privacy manifest declares nothing collected, nothing tracked.

## License

MIT

---

*[ennui-help.humanapp.ca](https://ennui-help.humanapp.ca)*
