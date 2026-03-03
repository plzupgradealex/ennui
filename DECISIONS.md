# Ennui - Design Decisions

## Concept
Ambient world explorer. You just watch, breathe, and drift. Anti-doomscroll.
Ethereal, mysterious, innocent and kind. Willing to trade usability for beauty and mystery.

## Scenes (v2)
1. **Cosmic Drift** - warm nebula palette, 300 stars, 14 nebulae, smooth shooting stars, tap ripple effects
2. **Pixel Garden** - Sonic-the-Hedgehog-level pixel art at 384x256. 180s day/night cycle with sunset tinting, 3-layer parallax mountains, waterfall with splash, 120 grass blades, 12 detailed trees (oak/pine/willow), 50 flowers (cross/tulip/daisy), butterflies (day)/fireflies (night), pollen/petals, stream with sparkles, scrolling distant trees
3. **Deep Ocean** - bioluminescent depth zones, caustic light patterns, 8 light rays, 250 marine snow particles, 12 jellyfish with oral arms + trailing tentacles, 18 kelp strands with leaf blades, 14 coral formations (branching/fan/brain), bioluminescent plankton clouds, sea floor with rocks, depth pressure waves
4. **Desert Stars** - 500 temperature-varied stars, detailed milky way with dust lanes, multiple shooting stars, 5 dune layers with wind ripples, distant mesa/butte silhouettes, sand wisps, dust devils
5. **Ancient Ruins** - 7 columns (some broken) with fluting, lintels, scattered stones, 5-band aurora, 150 stars, mountain silhouettes, 50 fireflies with glow halos, tap-burst firebug effect, golden floating dust, volumetric mist
6. **Salt Lamp** - organic Himalayan salt lamp body, 18 internal lava blobs, ambient glow, specular highlight
7. **Conservatory** - Victorian greenhouse with rain on glass, steam plants, condensation
   8. **Old Car** - Inside a 1950s land-yacht bench-seat car at night in a snowstorm: incandescent dash glow, chrome radio knobs and AM/FM tuner, wiper blades sweeping, utility poles and barns in the dark. Also available as **Old Car 3D** (SceneKit).

## UX Philosophy
- **Dreamy intro**: 2.5s breathing light orb on black, then 3.5s slow dissolve into first scene
- **Ethereal scene picker**: floating glowing orbs (not traditional buttons or text), radial gradients with pulse animation
- **Crossfade transitions**: 2s opacity crossfade between scenes (previous scene lingers beneath)
- **Vignette overlay**: always-on radial gradient edge darkening for dreamlike focus
- **Discoverability through mystery**: no labels, no instructions — hover near bottom, press space, or double-tap to discover the picker
- **Innocent & kind**: haiku prompts emphasize gentleness, wonder, and calm

## Tech Stack
- **SwiftUI** + **Canvas** for all rendering (no SpriteKit, no Metal - portable)
- **MultipeerConnectivity** for P2P sharing nearby (encryption: `.required` for App Store compliance)
- **FoundationModels** for on-device AI haiku (Apple Neural Engine)
- **NSViewRepresentable** (`MouseTrackingView`) for cursor hover detection on macOS
- macOS 14+ deployment target, future iOS
- **XCUITest** suite: 12 automated tests covering launch, intro, picker, scene switching, keyboard nav, haiku toggle, interaction, rapid switching stability, extended run

## Keyboard Shortcuts
- **←/→** arrows: switch scenes
- **Space**: show picker
- **H**: toggle haiku overlay
- **Double-tap**: show picker
- **Triple-tap**: toggle haiku
- **Single tap**: scene-specific interaction (firefly bursts, ripples, etc.)

## Multiplayer
- MultipeerConnectivity auto-discovers nearby peers (Bonjour)
- Auto-accept invitations (chill, no friction)
- Encryption: `.required` (App Store rule)
- Scene changes sync to connected peers
- Future: SharePlay via Group Activities framework for internet sharing

## Future Ideas
- Seasonal variations (spring cherry blossoms, autumn leaves, winter snow)
- Solar system locations (Mars dust storms, Europa ice, Saturn rings)
- More retro modes (Amiga, PS1 low-poly, N64 fog)
- Ambient generative music via AudioKit or AVAudioEngine
- Metal compute shaders for particle systems (GPU acceleration)
- iOS companion app with same codebase
