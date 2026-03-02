# Ennui

An ambient scene viewer for macOS. 29 procedural Canvas scenes rendered at
60fps via Metal GPU compositing. No data collection, no accounts, no onboarding.
Watch, breathe, tap sometimes.

---

## Requirements

- **macOS 26.0 (Tahoe)** or later
- **Apple Silicon Mac** (M1, M2, M3, M4 — no Intel)
- **Xcode 18** with command-line tools

If you don't have Xcode installed:
1. Install Xcode from the Mac App Store
2. Open Terminal and run: `xcode-select --install`

---

## Install

```bash
git clone <repo-url> ennui
cd ennui
chmod +x scripts/install.sh
./scripts/install.sh
```

The script builds from source and copies Ennui.app to `/Applications`.  
First build takes ~60–90 seconds. After that, launch it from your Applications
folder or Spotlight.

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| ← → | Previous / next scene |
| Space | Show scene picker |
| Double-click | Show scene picker |
| H | Toggle haiku overlay |
| ? | About panel |
| S | Toggle sharing (peer sync) |
| Click/Tap | Scene-specific interaction |

Hover near the bottom of the window to reveal the scene picker.

---

## What It Is

29 hand-crafted procedural scenes — drifting nebulae, rainy conservatories,
medieval villages settling for night, a Japanese neighborhood in the rain,
Ontario countryside at dusk, a Windows 95 screensaver, Himalayan salt lamps,
pixel-art gardens, bioluminescent deep oceans, and more.

Every scene runs on a Canvas at 60fps, composited via Metal on the GPU.
No images, no video files — everything is drawn from math and code.

Tapping does something gentle in each scene: a firefly, a ripple, a lantern, a
splash, a warmth pulse. Nothing resets, nothing startles.

Haiku overlay (press H) generates poems with on-device AI, or falls back to
hand-written ones.

---

## Privacy

Zero data collection. No analytics, no telemetry, no network calls (except
optional peer sync on local network). The privacy manifest declares nothing.

---

## Building Manually

If you prefer to build yourself instead of using the install script:

```bash
cd ennui
xcodebuild -project Ennui.xcodeproj -scheme Ennui -configuration Release build
```

The built app will be in:  
`~/Library/Developer/Xcode/DerivedData/Ennui-*/Build/Products/Release/Ennui.app`

---

*Made by Alex Ruppel — alex.ruppel@pm.me*
