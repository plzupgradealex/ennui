# Ennui - Design Decisions

## Concept
Ambient world explorer. You just watch, breathe, and drift. Anti-doomscroll.

## Scenes (v1)
1. **Cosmic Drift** - float through a gentle nebula with twinkling stars and shooting stars
2. **Pixel Garden** - SNES/Genesis-style retro pixel art garden with day/night cycle, flowers, butterflies/fireflies
3. **Deep Ocean** - bioluminescent jellyfish and particles in the deep sea
4. **Desert Stars** - sand dunes under a milky way with shooting stars
5. **Ancient Ruins** - columns bathed in aurora light with fireflies and mist

## Tech Stack
- **SwiftUI** + **Canvas** for all rendering (no SpriteKit, no Metal - keeps it simple and portable)
- **MultipeerConnectivity** for P2P sharing nearby (works on both macOS and iOS)
- macOS target first, iOS later (same SwiftUI code)
- Deployment target: macOS 14+

## NPU / Apple Intelligence
- Use `FoundationModels` framework (macOS 26 / Tahoe) to generate on-device calming haiku/poetry/thoughts
- These appear as gentle text overlays that fade in and out on each scene
- Runs entirely on-device via Apple Neural Engine — no network needed
- Fallback: static curated quotes if FoundationModels unavailable

## Multiplayer
- MultipeerConnectivity auto-discovers nearby peers
- Auto-accept invitations (it's chill, no friction)
- Future: sync which scene you're both watching

## Future Ideas
- Seasonal variations (spring cherry blossoms, autumn leaves, winter snow)
- Solar system locations (Mars dust storms, Europa ice, Saturn rings)
- More retro modes (Amiga, PS1 low-poly, N64 fog)
- Interactive elements (tap to create ripples, particles)
- Ambient generative music
