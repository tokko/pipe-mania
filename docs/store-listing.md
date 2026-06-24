# Store listing scaffold — Aqueduct (working title)

> Scaffold only (epic E7a). The name is the trademark-safe placeholder `Config.GAME_NAME`
> ("Aqueduct") — **run a trademark search and finalize the name before any store submission**
> ("Pipe Mania" / "Pipe Dream" are trademarks). Fill the TODOs before publishing.

- **Title:** Aqueduct
- **Package:** org.aqueduct.game  (placeholder — confirm ownership)
- **Category:** Puzzle
- **Short description (≤80 chars):** Route the pipes, run the water — build the longest leak-free line.
- **Full description:**
  A real-time pipe puzzle. In the calm build phase you place forced pipe pieces to route water from
  the inlet to the outlet — go long and winding, because your score is the length of the shortest
  route the water actually takes. Then tap GO and the water verifies your work: reach the outlet to
  clear and advance to a harder board; spring a leak or touch a bomb and the run ends. Endless
  score-chase, one mistake ends it.
- **Content rating:** TODO (IARC questionnaire — expected Everyone)
- **Screenshots:** TODO (phone portrait: build phase w/ route readout; flow w/ scored-route highlight; bomb proximity)
- **Feature graphic / icon:** TODO (authored art)
- **Privacy policy URL:** TODO (required once ads/analytics SDKs are live — see E7b stubbed services)
- **Monetization:** F2P hybrid (rewarded video / remove-ads IAP / cosmetics) — stubbed this build (E7b), live wiring needs accounts.

## Build (once `tools/android-preflight.ps1` is GREEN)
1. Install Godot 4.6.2 Android export templates; set editor Android SDK + Java SDK paths; generate a debug keystore.
2. `tools/android-preflight.ps1`  → expect `PREFLIGHT: GREEN`.
3. `godot --headless --export-debug Android build/aqueduct.apk`
4. Smoke: install on an AVD, play a fixed-seed board to a clear (design's on-device smoke test).
