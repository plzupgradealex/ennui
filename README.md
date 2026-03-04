# Ennui

An ambient scene viewer for macOS. 70 procedural scenes rendered at 60 fps
via Metal GPU compositing. No data collection, no accounts, no onboarding.
You watch, breathe, tap sometimes.

An anti-doomscroll tool.

## Scenes

Every scene is drawn entirely from math and code — no images, no video files.
34 scenes use SwiftUI Canvas at 60 fps, flattened to a single Metal texture
each frame. Each Canvas scene also has a 3D SceneKit counterpart — the same
world reimagined as a low-poly diorama with a slowly orbiting camera. Two
additional SceneKit-exclusive scenes bring the total to 70.

### Canvas scenes (34)

| | | |
|---|---|---|
| Ancient Ruins | Art Deco LA | Aurora Borealis |
| Captain Star | Cel-Shaded Rainy Day | Celestial Scroll Hall |
| Conservatory | Cosmic Drift | Deep Ocean |
| Desert Starscape | Enchanted Archives | Floating Kingdom |
| Forgotten Library | Gouraud Solar System | Greeting the Day |
| Jeonju Night | Late Night Rerun | Lush Ruins |
| Medieval Village | Midnight Motel | Minnesota Small Town |
| Mystify | Night Train | Nonsense & Lullabies |
| Old Car | Ontario Countryside | Paper Lantern Festival |
| Quiet Meal | Retro Garden | Retro PS1 |
| Salt Lamp | Shimizu Evening | Urban Dreamscape |
| Voyager Nebula | | |

### SceneKit 3D scenes (36)

Every Canvas scene above has a "3D" counterpart, plus two SceneKit-exclusive
scenes: **Inner Light 3D** and **Wireframe City 3D**.

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

**Canvas scenes** are SwiftUI `TimelineView` driving a `Canvas` at 60 fps.
`.drawingGroup(opaque: false, colorMode: .extendedLinear)` composites the
Canvas into a single Metal texture on the GPU. `.allowedDynamicRange(.high)`
enables HDR on XDR displays. All animation is derived from elapsed time —
Canvas closures are pure functions of `t`.

**3D scenes** use SceneKit (`SCNView` via `NSViewRepresentable`). Each builds
a low-poly diorama procedurally — no model files — with ambient lighting,
particle systems, and a slowly orbiting camera. They share the same
interaction model (tap for gentle effects) and crossfade into/out of Canvas
scenes seamlessly.

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
