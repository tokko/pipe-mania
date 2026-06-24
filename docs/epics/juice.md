# Epic E6 — Juice (feel: audio cues, colorblind cues, bomb warning)

Implements design section: juice. The design's art/feel pass. **Acceptance #4 explicitly states
"done NOT gated on subjective art/music quality"** — so E6 builds the *behaviorally-provable* feel
WIRING (SFX event→id mapping fires per event; cell types distinguishable by SHAPE not hue alone;
bomb proximity warning at exactly 2 cells) and treats bespoke art, synthesized audio fidelity, and
animation polish as the **manual/screenshot tier** (a human evaluates look/sound). Already built:
scored-route highlight + bomb shake (E3), placement shake + invalid haptic (E2).

## Design decisions (assumptions — logged for council scrutiny)

- **Audio cues = a map + a thin manager** (`scripts/audio_cues.gd`): `CUES = {place, invalid, go,
  clear, leak, bomb}` → string sfx ids. An `AudioManager` (autoload) `play(event)` looks up the id
  and records `last_id`. **The recorded id IS the whole of acceptance #2** ("each gameplay event logs
  its mapped SFX id") — real `AudioStreamGenerator` synthesis is the deferred manual-audio tier,
  explicitly authorized by acceptance #4. (Council: stated plainly so the proof isn't read as hollow.)
  `play()` is `Settings.audio_enabled`-gated for real playback but ALWAYS records last_id (so the gate
  is deterministic regardless of the audio toggle). Main fires a cue at each event site (below).
- **Cue sites in Main (council enumeration — all six, no doubles):** `place_at` success branch →
  `place`; `place_at` false branch (next to `_bv.shake()`) → `invalid`; `_start_flow` (after the
  phase guard, once) → `go`; `_on_outcome` → `clear` / `leak` / `bomb` by Outcome.
- **Colorblind: per-cell-type SHAPE marker that actually DRAWS** (`Tile.cell_marker(cell_type)` →
  distinct marker id; `Tile._draw` branches on it to draw a real glyph — BOMB a spiky ring, BLOCKED
  an X/hatch, OPEN none) so types are distinguishable WITHOUT hue (pipes are already shape-encoded).
  GUT asserts `cell_marker` is pairwise-distinct AND `_draw` consumes it (not a stub that passes GUT
  but fails the eye); the literal colorblind-sim screenshot is the manual tier.
- **Bomb proximity glow = MANHATTAN distance ≤ 2** (`GameState.is_near_bomb(x,y)`), consistent with
  the orthogonal bomb-*fail* (adjacency = Manhattan 1). Council BLOCKER (Chebyshev vs Manhattan
  disagree on diagonals): settled to Manhattan because the bomb mechanic is orthogonal. Acceptance #3
  "activates at exactly 2 cells" = radius 2: a cell at Manhattan distance ≤2 glows, distance 3 does
  NOT (the control). `Tile.refresh()` gains a `near_bomb` param; `BoardView.refresh` passes
  `gs.is_near_bomb(x,y)` per cell; `_draw` renders the glow when set.
- **Deferred (logged, NOT acceptance-gating, Simplicity-First):** clear-celebration beat (E4 NIT —
  risks the run-loop timing), live high-score display (E4 NIT), relaxed tutorial clock + banner
  safe-area (E5 NITs). These are real polish but outside E6's acceptance; left as reflection items
  unless cheap+safe.

## Sprint breakdown

- **E6.1** [integration] `audio_cues.gd` (event→sfx_id map) + `AudioManager.play(event)` (records
  last_id; `Settings.audio_enabled` gate). Main fires cues: place / invalid / GO / clear / leak /
  bomb. Scripted: each event → its mapped sfx id recorded.
- **E6.2** [logic+integration] colorblind cell-type shape markers (`Tile.cell_marker` distinct per
  type) + bomb proximity glow (`GameState.is_near_bomb`, Chebyshev ≤2). GUT (test-first): markers
  all-distinct; is_near_bomb true at dist≤2, false at dist 3 (control). Tile draws marker+glow.

## Test strategy

- **Headless [logic] (GUT):** `is_near_bomb` — a bomb at (c): cells at Manhattan distance 1 and 2
  return true, distance 3 returns false (control); no-bomb board → all false. `cell_marker(OPEN)`,
  `cell_marker(BLOCKED)`, `cell_marker(BOMB)` are pairwise distinct (control: not all the same).
- **[integration]** scripted Main: drive each gameplay event and assert `AudioManager.last_id` ==
  the mapped sfx id (SFX_PLACE/SFX_CLEAR/SFX_LEAK/SFX_BOMB/…); assert a bomb-adjacent board reports
  `is_near_bomb` cells > 0.

## Proof (section: juice)

`tools/run-gate.ps1` (is_near_bomb radius control + distinct cell markers) green, AND scripted Main
shows each event mapping to its SFX id + proximity glow active near a bomb. The literal
colorblind-simulation screenshot + audio-fidelity + art quality are the MANUAL tier (acceptance #4:
done is NOT gated on subjective art/music quality). Real entry point, failing controls (dist-3 no
glow; markers-distinct), positive liveness.

## Notes

- No extension skill — E6 adds no `add-<concept>` extensible variants.
- Music deferred entirely (design); SFX synthesis fidelity = manual. The MAP + invocation is proven.
