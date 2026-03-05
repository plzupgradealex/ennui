# Ennui — Code Review Recommendations

*Prepared after a full read of the codebase. Ordered roughly by impact.  
Context: macOS 26+, Swift, SwiftUI Canvas (2D) + SceneKit/Metal (3D), AVAudioEngine, MultipeerConnectivity.*

---

## 1. SceneKind is a 521-line maintenance trap

`SceneType.swift` is a single enum with 73 cases and **six exhaustive switch statements** — `displayName`, `accessibilityDescription`, `tapHint`, `icon`, `tint`, `audioMood` — plus another enormous `switch` in `ContentView.sceneView(for:)`. Adding one scene requires editing 7+ separate blocks in 2 files.

**Recommendation:** Introduce a `SceneDescriptor` struct that holds all the static metadata, and keep `SceneKind` as a thin enum that vends it:

```swift
struct SceneDescriptor {
    let displayName: String
    let accessibilityDescription: String
    let tapHint: String
    let icon: String
    let tint: Color
    let audioMood: String
    let is3D: Bool
}
```

Store a `private static let registry: [SceneKind: SceneDescriptor] = [...]` lookup and delegate every computed property to it. Adding a scene then becomes one dictionary entry. The `sceneView(for:)` switch in `ContentView` could similarly be driven by a factory closure registered alongside the descriptor.

---

## 2. `kSceneCount` in UI tests is wrong and will silently miss scenes

`EnnuiUITests.swift:4` hard-codes `kSceneCount = 37`. The actual `SceneKind.allCases.count` is **73**. The cycle-all-scenes tests only cover half the scenes. No test will catch a crash in, say, `VoyagerNebula3DScene` or `WireframeCity3DScene`.

**Recommendation:** Derive the count from the enum itself. The simplest fix for the test file:

```swift
// No Ennui module import needed — just use the raw count
private let kSceneCount = 73  // SceneKind.allCases.count at time of writing
```

Better: add a test-helper target that imports Ennui so tests can write `SceneKind.allCases.count` directly and never go stale. Until then, at minimum update the constant and add a comment linking to `SceneType.swift`.

---

## 3. `RandomUtils.swift` contains a verbatim duplicate of the same algorithm

`SplitMix64.next()` (the struct method) and the free function `nextUInt64(_:)` are **byte-for-byte identical**. `nextDouble(_:)` duplicates `SplitMix64.nextDouble()` the same way. The free functions appear to exist because some early scenes captured `rng` by value and needed free-function call syntax, but the struct methods work equally well.

**Recommendation:** Delete the free functions and use the struct methods everywhere. If call-site convenience is needed, add an `extension SplitMix64` with mutating helpers:

```swift
// Remove these:
func nextUInt64(_ rng: inout SplitMix64) -> UInt64 { ... }
func nextDouble(_ rng: inout SplitMix64) -> Double { ... }

// They are already on the struct:
mutating func next() -> UInt64 { ... }
mutating func nextDouble() -> Double { ... }
```

---

## 4. Documentation is stale — scene counts are wrong

`README.md` and `DECISIONS.md` both describe **70 scenes** (34 Canvas + 36 SceneKit). The actual totals are **35 Canvas + 38 SceneKit = 73 scenes**. The scenes added since those docs were written: `oldCar` (Canvas), `retroGarden3D`, `celShadedRainyDay3D`, `retroPS13D`, `greetingTheDay3D`, `mystify3D`, `nonsenseLullabies3D`, `potterGarden3D`, `lastAndFirstMen3D`.

**Recommendation:** Update both files. Also update the scene list table in `README.md` to include `Old Car`, and update `DECISIONS.md`'s scene count and list. While there, update the tech stack note — `LastAndFirstMen3DScene` uses **Metal + MTKView**, not SceneKit, so the "36 3D scenes via SceneKit" description is no longer accurate.

---

## 5. All 35 "generic" 3D scene icons are the same `"cube"` SF Symbol

The `icon` property in `SceneType.swift` returns `"cube"` for 35 of the 38 3D scenes. In the picker these show as identical glyphs with only colour to distinguish them — not ideal for discoverability.

**Recommendation:** Assign scene-appropriate SF Symbols to every 3D scene. Quick pass to get started (use `cube` only if nothing better fits):

| Scene | Suggested icon |
|---|---|
| cosmicDrift3D | `sparkles` |
| voyagerNebula3D | `sparkle.magnifyingglass` |
| desertStarscape3D | `moon.stars.fill` |
| deepOcean3D | `water.waves.slash` |
| ancientRuins3D | `building.columns.fill` |
| auroraBorealis3D | `wind.snow` |
| saltLamp3D | `flame.fill` |
| conservatory3D | `humidity.fill` |
| quietMeal3D | `cup.and.saucer.fill` |
| artDecoLA3D | `building.columns.fill` |
| urbanDreamscape3D | `building.2.fill` |
| shimizuEvening3D | `cloud.rain.fill` |
| nightTrain3D | `train.side.front.car` |
| ontarioCountryside3D | `sun.horizon.fill` |
| minnesotaSmallTown3D | `house.fill` |
| midnightMotel3D | `bed.double.fill` |
| forgottenLibrary3D | `books.vertical.fill` |
| enchantedArchives3D | `book.and.wrench` |
| celestialScrollHall3D | `scroll.fill` |
| floatingKingdom3D | `cloud.sun.fill` |
| paperLanternFestival3D | `lamp.desk.fill` |
| captainStar3D | `globe.americas.fill` |
| gouraudSolarSystem3D | `globe.europe.africa.fill` |
| retroGarden3D | `leaf.fill` |
| celShadedRainyDay3D | `cloud.rain.fill` |
| retroPS13D | `gamecontroller.fill` |
| greetingTheDay3D | `sunrise.fill` |
| mystify3D | `display` |
| nonsenseLullabies3D | `paintbrush.pointed.fill` |
| potterGarden3D | `leaf.fill` |
| innerLight3D | `light.max` |
| wireframeCity3D | `grid` |
| lastAndFirstMen3D | `timeline.selection.2` |

---

## 6. MultipeerManager auto-invites every discovered peer unconditionally

`browser(_:foundPeer:)` calls `browser.invitePeer(peerID, to: session, ...)` immediately for every peer found on the network. This means:

- A user who has **not** opted into sharing can still receive (and even generate) invitations on a busy network, because the browser is started alongside the advertiser.
- If two Ennui instances both have sharing enabled and both discover each other, they will each invite the other simultaneously, producing two pending invitations that race.
- There is no deduplication; if a peer is rediscovered (e.g., after a Bluetooth hiccup), it will be re-invited.

**Recommendation:** Only start browsing if the user has opted in (`startSharing()`), and track which peer IDs have already been invited:

```swift
private var invitedPeers: Set<MCPeerID> = []

func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, ...) {
    guard !session.connectedPeers.contains(peerID),
          !invitedPeers.contains(peerID) else { return }
    invitedPeers.insert(peerID)
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
}

func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    invitedPeers.remove(peerID)
}
```

Also clear `invitedPeers` in `stopSharing()`.

---

## 7. `ContentView` is 737 lines and mixes too many concerns

`ContentView` is responsible for: scene rendering, crossfade logic, intro animation, picker UI, keyboard shortcuts, mouse tracking, peer sync, audio control, rating overlay, share consent overlay, peer invitation overlay, and preload management. This makes it hard to read, test, or modify any one concern without touching the whole file.

**Recommendation:** Extract at minimum:

1. **`ScenePickerView`** — the `etherealPicker` and `orbRow` views  
2. **`PeerConsentView`** — `shareConsentOverlay` and `peerInvitationOverlay`  
3. **`SceneTransitionController`** (plain class/struct, not a View) — `transitionToScene`, `switchScene`, `preloadNeighbors`, `warmingScenes`, `crossfade`, `previousScene`

`ContentView` itself should thin down to layout, modifier chains, and delegation.

---

## 8. `HaikuGenerator` stores a session it never reads back

In `HaikuGenerator.generate(for:)`:

```swift
let session = LanguageModelSession()
self.session = session          // stored on actor
let response = try await session.respond(to: prompt)  // local var used
```

`self.session` is written every call but never read; the local `session` is always what's used. The likely intent was to keep the session alive for re-use (LanguageModelSession can accumulate context), but the current code creates a brand-new session on every haiku request.

**Recommendation:** Either:
- Remove `private var session: LanguageModelSession?` and not store it (if stateless is fine — each haiku is independent)
- Or actually reuse it: check `if session == nil { session = LanguageModelSession() }` then call `session!.respond(to:)`

If re-using the session for accumulated context is desired, be aware that long sessions can grow large — add a reset mechanism (e.g., new session every N haikus, or after scene changes).

---

## 9. `AboutView`'s dismiss mechanism is fragile

`dismiss()` in `AboutView` manually animates `opacity` to 0, then calls `isPresented = false` via `DispatchQueue.main.asyncAfter(deadline: .now() + 0.4)`. If the user dismisses twice quickly (double-tap on backdrop), two async callbacks are queued and `isPresented` is set false twice. If the enclosing view is deallocated before 0.4s, the callback captures a dangling reference.

**Recommendation:** Use SwiftUI's built-in presentation dismissal which handles this safely, or at minimum guard against double-dismiss:

```swift
private var isDismissing = false

private func dismiss() {
    guard !isDismissing else { return }
    isDismissing = true
    withAnimation(.easeIn(duration: 0.35)) { opacity = 0; contentOffset = 8 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        isPresented = false
    }
}
```

Similarly, `StarRatingOverlay.dismiss()` has the same pattern and the same risk.

---

## 10. `EDRWindowConfigurator` accesses `view.window` in a `DispatchQueue.main.async` — unreliable timing

In `EDRWindowConfigurator.makeNSView(context:)`:

```swift
DispatchQueue.main.async {
    if let window = view.window {   // may be nil if view isn't in hierarchy yet
        window.colorSpace = .displayP3
        ...
    }
}
```

On a slow machine (or in testing), the view may not be added to the window hierarchy before the next main-queue turn. The window access silently fails and the app never gets P3/EDR configured.

A safer pattern is to use `viewDidMoveToWindow` via an `NSView` subclass:

```swift
class EDRConfigView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.colorSpace = .displayP3
        wantsLayer = true
        layer?.wantsExtendedDynamicRangeContent = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.wantsExtendedDynamicRangeContent = true
    }
}
```

Then `makeNSView` just returns `EDRConfigView()` with no async.

---

## 11. `AmbientAudioEngine` raw pointer management needs documentation and safety review

The engine allocates 9 arrays of `UnsafeMutablePointer<Double>` in `init` and deallocates in `deinit`. The render closure captures these raw pointers and reads/writes them from the **real-time audio thread** while the main thread also reads `vAmp`, `vFreq`, etc. in `scheduleNote()` and `stop()`. There is no lock or memory barrier documented beyond the comment "ARM64 aligned 8-byte access is atomic."

This works in practice on Apple Silicon, but:
- It is not guaranteed to be safe on future architectures or under ARC's optimizer
- Clang/LLVM may reorder stores across the "barrier" invisible to the audio thread
- The `stop()` method zeroes the pointers while the engine may still be in a render callback

**Recommendation:**
1. Add a `// THREAD SAFETY:` doc-comment block to the class explaining the threading model explicitly
2. Use `stop()` the AVAudioEngine before zeroing voice data in `stop()` — `engine.stop()` already does this, but document that the order is intentional
3. Consider replacing the raw pointers with a fixed-size `[Double]` array with `withUnsafeMutableBufferPointer` in the render closure for cleaner ownership semantics (performance is identical on modern Swift)

---

## 12. `SceneKind` is ordered 2D-first, but arrow navigation doesn't respect any thematic grouping

`SceneKind.allCases` lists 35 2D scenes followed by 38 3D scenes. Arrow-key navigation steps through `allCases` in order, which means pressing right from `oldCar` (case 35) lands on `oldCar3D` (case 36). This pairing is nice, but all subsequent right-arrow steps proceed through the 3D block and never return to a 2D scene until wrapping all the way around.

**Recommendation:** Consider interleaving 2D/3D pairs so that pressing right from a 2D scene always goes to the same scene's 3D counterpart, and then to the next 2D scene — creating a rhythm of `2D → 3D → 2D → 3D`. Or, add a preference for "keep in 2D / keep in 3D" mode. At minimum, document the navigation order in `DECISIONS.md`.

---

## 13. No SwiftUI `#Preview` macros anywhere in the codebase

None of the 73+ scene files, overlays, or UI components have `#Preview` blocks. This means every iteration cycle requires building and running the full app, navigating to the right scene, and waiting through the 6-second intro. For a project with this many visual components, this is a real velocity bottleneck.

**Recommendation:** Add `#Preview` blocks to at minimum:
- `HaikuOverlayView` (can be tested with a static string)
- `StarRatingOverlay`
- `AboutView`
- `ContentView` (with mock `multipeerManager`)
- 2–3 representative Canvas scenes (e.g., `CosmicDriftScene`, `SaltLampScene`)

For Canvas scenes a minimal preview just needs a fixed `InteractionState()`:

```swift
#Preview {
    CosmicDriftScene(interaction: InteractionState())
        .frame(width: 800, height: 600)
}
```

---

## 14. `allowsCameraControl = true` in 3D scenes conflicts with the app's ethos

`MedievalVillage3DScene` (and possibly others — check all `SCNView` setup sites) sets `view.allowsCameraControl = true`. This lets users drag to orbit and pinch to zoom the SceneKit camera, which:
- Conflicts with the "just watch" philosophy described in `DECISIONS.md`
- Competes with `MagnifyGesture` in `ContentView` which is meant for app-level zoom

**Recommendation:** Audit all 3D scenes for `allowsCameraControl`. If the intent is a slowly orbiting scripted camera, this should be `false`. If user orbit is intentional for some scenes, document it in `DECISIONS.md`.

---

## 15. `pickerTimer` uses `Timer.scheduledTimer` with a `DispatchQueue.main.async` inside the callback — unnecessary nesting

In `showPickerBriefly(duration:)`:

```swift
pickerTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
    DispatchQueue.main.async {
        withAnimation(.easeInOut(duration: 1.2)) { showPicker = false }
    }
}
```

`Timer.scheduledTimer` fires on the run loop it was scheduled on. Since this is always called from the main thread (it reads/writes `@State`), the timer already fires on the main thread. The inner `DispatchQueue.main.async` is redundant.

**Recommendation:**

```swift
pickerTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
    withAnimation(.easeInOut(duration: 1.2)) { self?.showPicker = false }
}
```

(Also note: `ContentView` is a struct, so `[weak self]` isn't strictly needed here — `self` is captured by value. The bigger fix is moving to `Task`-based async/await for all such timers.)

---

## 16. `RatingManager` silently swallows disk errors

Both `load()` and `save()` use `try?`, silently dropping file I/O errors. A disk-full or permissions error will make ratings disappear without any indication.

**Recommendation:** At minimum, log errors in debug builds:

```swift
private func save() {
    guard let data = try? JSONEncoder().encode(ratings) else { return }
    do {
        try data.write(to: fileURL, options: .atomic)
    } catch {
        #if DEBUG
        print("[RatingManager] save failed: \(error)")
        #endif
    }
}
```

For a production app, consider surfacing persistent write failures gracefully (e.g., degrading gracefully — no rating prompt if write fails).

---

## 17. `WarmingScenes` preload gap after transitions

In `transitionToScene(_:)`:

```swift
warmingScenes.remove(scene)
// ...
DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
    previousScene = nil
    warmingScenes.removeAll()    // 1. clears all preloads
}
preloadNeighbors(of: scene)      // 2. schedules insert after 0.5s
```

After 2.5s the set is cleared, but the neighbors were already added at 0.5s — so they're cleared too. After 2.5s, no neighbors are warming. Only a subsequent transition or hover will add them back.

**Recommendation:** Re-preload neighbors *after* the clear:

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
    previousScene = nil
    warmingScenes.removeAll()
    preloadNeighbors(of: currentScene)   // re-establish preload for current scene
}
```

---

## 18. `HaikuOverlay.swift` fallback haiku dictionary is 400+ lines — move to a data file

`HaikuOverlayView` contains a 400-line `static let fallbackHaiku: [SceneKind: [String]]` literal hardcoded in Swift. This is hard to edit (requires recompile) and inflates the binary with string data.

**Recommendation:** Extract to `fallback_haiku.json` in the bundle:

```json
{
  "cosmicDrift": [
    "Stars drift through the void\nSilent rivers of pale light\nBreathing with the dark",
    ...
  ],
  ...
}
```

Load once at startup via `Bundle.main.url(forResource:withExtension:)`. This enables editing haiku without recompiling, and makes the file easier to review and contribute to.

---

## 19. Intro animation uses `sleep(8)` in UI tests — extremely fragile

`waitForIntro()` in `EnnuiUITests.swift` calls `sleep(8)` unconditionally. This adds 8 seconds to every test and will fail on slow CI machines where the intro takes longer. Tests already pass 12-second timeouts to `waitForExistence`, making the `sleep(8)` in `waitForIntro()` a double-wait for most tests.

**Recommendation:** Replace with `waitForExistence(timeout:)` on a stable UI element:

```swift
private func waitForIntro() {
    // Wait for picker orbs to appear — they show after the 6s intro
    _ = app.buttons.firstMatch.waitForExistence(timeout: 15)
    sleep(2)  // brief buffer for initial picker auto-dismiss
}
```

This is faster on fast machines and more resilient on slow ones.

---

## 20. Future: iOS / visionOS portability consideration

The app targets macOS exclusively, but `DECISIONS.md` mentions "future iOS companion app". Currently:

- `MouseTrackingView` uses `#if os(macOS)` guards (good)
- `NSViewRepresentable` is used pervasively in all 3D scenes
- `NSColor` appears directly in 3D scene code (e.g., `MedievalVillage3DScene`)
- `AppDelegate` is `NSApplicationDelegate`-only

None of this blocks iOS today, but the delta will grow with each new scene. **Recommendation:** Establish a practice of using `UIViewRepresentable`/`NSViewRepresentable` type aliases and `PlatformColor` = `UIColor` / `NSColor` bridges now, so the iOS port doesn't require touching every scene file.

---

*End of recommendations. These are prioritised top-to-bottom: items 1–5 have the highest maintenance leverage; items 6–12 are correctness/reliability concerns; items 13–20 are polish and future-proofing.*
