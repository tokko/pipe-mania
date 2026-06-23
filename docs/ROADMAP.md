# ROADMAP — pipe game (crunch-consumable)

Design rationale: `docs/DESIGN.md`. This file is the static epic backlog, the **pinned
constants**, the **test fixtures**, and the acceptance criteria. Kanban
(`.auto-sprint-board/state.json`) is the live source of truth.

Engine: Godot 4 (GDScript), Android-only autonomous scope. **Epics are a dependency chain —
execute in order.** Within an epic, `[parallel]` sprints may fan out; others are sequential.

### Gate tiers (a sprint is gated at its tier — crunch must not try to headless-test view code)
- **[logic]** — pure GDScript, headless GUT, full TDD (failing test first + failing control).
- **[integration]** — `mcp__godot__run_project` + `get_debug_output`; assert logged state.
- **[screenshot]** — `mcp__godot__` editor/desktop run + screenshot; visual/legibility checks.

### Determinism (foundational)
All RNG seeded; `GameState` advances via explicit `step()` (never wall-clock). **Exact-value
assertions use hand-authored fixtures (below), NOT generated seeds.** Seeds are used only for
property tests (e.g. "every generated board is solvable").

---

## Pinned tuning constants — `DifficultyConfig(n)`, n = board index (0-based)
Tunable in E5, but the constants live in code and tests assert these exact values. Changing a
constant means changing its asserted value in the same commit.

| param | formula | n=0 | n=5 | n=15 |
|---|---|---|---|---|
| `build_seconds` | `max(8, 25 - n)` | 25 | 20 | 10 |
| `grid_w` | `min(9, 5 + n/3)` (int div) | 5 | 6 | 9 |
| `grid_h` | `min(13, 7 + n/2)` (int div) | 7 | 9 | 13 |
| `bombs` | `min(grid_w*grid_h/8, n/3)` | 0 | 1 | 5 |
| `blocked` | `min(grid_w*grid_h/6, 1 + n/2)` | 1 | 3 | 8 |
| `w_straight` | `max(25, 45 - n)` | 45 | 40 | 30 |
| `w_bend` | `40` | 40 | 40 | 40 |
| `w_cross` | `min(35, 15 + n)` | 15 | 20 | 30 |

Grid caps (9×13) keep cells ≥44 dp in portrait. Hazard caps keep a solution feasible.

## Test fixtures — hand-authored boards with known outcomes (the exact-value contracts)
| fixture | layout intent | expected outcome |
|---|---|---|
| `FX_STRAIGHT8` | open corridor, only an 8-cell route fits | clear, **score = 8** |
| `FX_SHORTCUT` | a 10-cell winding route AND a 4-cell shortcut both reach outlet | clear, **score = 4** (shortest); control: block the shortcut → **score = 10** |
| `FX_LEAK` | route left with one open end | flow **leaks → fail**; control: cap the end → clear |
| `FX_BOMB_ADJ` | route passes orthogonally adjacent to a bomb | **bomb fail**; control: 1-cell buffer → clear |
| `FX_CROSSOVER` | two perpendicular flows through one cross | channels **don't mix** (two separate wet paths) |
| `FX_UNCONNECTED` | inlet/outlet cannot connect | **score 0 AND run-end flag set** |
| `FX_OUTLET_VS_BOMB` | outlet reached on the same step as bomb-adjacency | **clear wins** (outlet checked first) |
| `FX_TUTORIAL` | fixed deterministic board for first-board onboarding | completable; completion = water reaches outlet |

---

## E0 — Project scaffold  *(no deps)*
- **S0.1** [integration] Godot 4 project + `project-skeleton` template (**merge, don't clobber** existing `.gitignore`/`.gitattributes`); git init; portrait, mobile renderer.
- **S0.2** [logic] GUT wired; `Config` singleton with `GAME_NAME` (trademark-safe placeholder); a passing test + a quarantined failing-control test.

**Acceptance:** headless GUT runs green; un-skipping the control test makes the suite red (gate is not a no-op).

---

## E1 — Core model (headless, all [logic])  *(deps: E0)* — pure GDScript, no Node deps
- **S1.1** `Board`: cell types (`open`/`blocked`/`bomb`), inlet/outlet with fixed edge dirs. `GameState` wraps `Board` + phase (`BUILD`/`FLOW`) + GO transition (phase lives in the core, so E3 needs no local flag).
- **S1.2** Seeded `BoardGen` + **solvability validation = cell-level BFS over open/non-bomb cells** (no edge semantics yet); **retry cap** N=50 then widen the board. (control: a hand-made unsolvable layout is rejected.)
- **S1.3** Seeded piece queue (forced top, no skip/pick, 5-preview); **piece + orientation model** (each piece exposes a set of open edges; rotation maps edges); placement + dry-pipe overwrite (control: overwriting **wet** pipe is rejected).
- **S1.4** Edge-connection graph; **crossover = two independent channel-pairs** (N–S, E–W).
- **S1.5a** Deterministic flow `step()` — water advances along connected edges.
- **S1.5b** Leak eval — front must exit an open edge into a cell with no matching pipe edge → leak.
- **S1.5c** Bomb-adjacency eval + clear eval, with **outlet-reach checked before bomb** (`FX_OUTLET_VS_BOMB`).
- **S1.6** **Shortest-route BFS scoring** over the wetted graph (`FX_SHORTCUT`); plus a **dry-graph route-length query** for the live build readout (the only consumer is E2/S2.3).
- **S1.7** `DifficultyConfig(n)` implementing the pinned table.

**Acceptance (fixtures + controls):** `FX_STRAIGHT8`→8; `FX_SHORTCUT`→4, control→10; `FX_LEAK` fails, control clears; `FX_BOMB_ADJ` fails, control clears; `FX_OUTLET_VS_BOMB` clears; `FX_CROSSOVER` channels don't mix; `FX_UNCONNECTED`→score 0 **and** run-end; forced queue rejects skip/pick; wet-overwrite rejected; `BoardGen` solvable across seeds 1..200; `DifficultyConfig` matches the table exactly at n=0/5/15; expected-vs-actual test count cross-checked.

---

## E2 — Rendering + build-phase input  *(deps: E1)*
- **S2.1** [integration] `BoardView`+`Tile` (vector `_draw`), tiles pooled at board-load; render from `GameState`.
- **S2.2** [integration] Tap-to-place via signals; valid-cell highlight on touch-**down**; invalid tap shake+buzz.
- **S2.3** [integration] HUD: **build countdown**, 5-piece preview, **live route-length readout** (calls S1.6 dry-graph query).
- **S2.4** [integration] In-run settings icon: rotation toggle (drives S1.3 orientation), audio, haptics.

**Acceptance:** on `FX_STRAIGHT8`, a scripted placement sequence yields a `get_debug_output` cell-state array **equal to the fixture's expected grid**; countdown decrements in BUILD; route readout matches the model's dry-route length; rotation toggle changes which edges a placed piece exposes (assert via model); cells render ≥44 dp at the 9×13 cap.

---

## E3 — Flow phase + outcomes  *(deps: E2)*
- **S3.1** [integration] GO / countdown-expiry → `GameState` FLOW phase; placing disabled in FLOW.
- **S3.2** [integration] `FlowAnimator` drives fill off `step()`.
- **S3.3** [integration] Clear (geyser + **scored-route highlight**), leak (splash), bomb (shake) outcomes.

**Acceptance:** loading `FX_STRAIGHT8` and triggering GO logs `clear` with **score = 8**; `FX_LEAK` logs `leak`, `FX_BOMB_ADJ` logs `bomb`, `FX_OUTLET_VS_BOMB` logs `clear`; the highlighted route cell-list **equals** the model's shortest route.

---

## E4 — Endless run loop  *(deps: E3)*
- **S4.1** [logic+integration] `Run` autoload owns the board→board loop (phase machine is already in core): board-clear → `DifficultyConfig(n+1)` → next board; run-score = Σ board scores. (logic-test the Σ + index increment; integration-test the wiring.)
- **S4.2** [integration] Fail → run-end screen; `SaveStore` persists high score + settings (JSON in `user://`); restart resets to n=0.

**Acceptance:** a scripted 3-board run (each a fixture with known score) logs run-score = the exact Σ; after a clear, board index increments; a new high score survives a `SaveStore` reload (re-instantiate, read back equal); restart returns index→0 and score→0.

---

## E5 — Difficulty curve + onboarding  *(deps: E4)*
- **S5.1** [logic] Lock `DifficultyConfig` to the pinned table (this replaces "playtest tuning" with concrete assertions); a sanity test that build_seconds is monotonically non-increasing and grids stay ≤ cap for n=0..30.
- **S5.2** [integration+screenshot] First-board tutorial on `FX_TUTORIAL` teaching forced pieces, GO/verify, and the shortest-route rule; scoring legibility (route readout + clear-time highlight) verified by **desktop-run screenshot** (no APK/AVD needed at this stage).

**Acceptance:** `DifficultyConfig` table test passes; monotonicity test passes; `FX_TUTORIAL` is completable and deterministic; screenshot shows the route-length readout during build and the highlighted route on clear.

---

## E6 — Juice  *(deps: E2, E3)*
- **S6.1** [screenshot] Vector/shader art (cells, pipes, water, bomb) — **colorblind-safe: shape/icon + contrast, not color alone**; verify under a colorblind-simulation screenshot.
- **S6.2** [integration] SFX via **built-in `AudioStreamGenerator`** (no GDExtension); event→SFX map: place→click, invalid→buzz, fill→glug, clear→burst, bomb→whump. Haptics on place/fail/clear. (assert each event triggers its sound id via logs.)
- **S6.3** [integration+screenshot] Particles + screen-shake; bomb proximity glow at a **defined threshold = water within 2 cells**.

**Acceptance:** colorblind-sim screenshot shows distinct cell types without relying on hue; each gameplay event logs its mapped SFX id; bomb glow activates at exactly 2 cells. "Done" is **not** gated on subjective art/music quality (music = deferred swap point).

---

## E7a — Android export  *(deps: E6)* — no credentials
- **S7a.1** [integration] **Preflight** Android SDK/NDK/export templates + debug keystore. **Policy: if absent, fail LOUDLY with exact remediation, mark E7a BLOCKED, and stub-and-continue** (game stays editor-playable; the APK artifact is the only thing blocked).
- **S7a.2** [integration] If preflight passes: build a runnable **debug APK**; store-listing scaffold (icon/copy/screenshots) under `GAME_NAME`. **AVD provisioning** is a documented preflight too — if no AVD, on-device smoke is marked BLOCKED, not failed.

**Acceptance (only if preflight green):** debug APK builds headless; android-emulator MCP installs on the AVD, plays `FX_STRAIGHT8`, screenshots a board-clear. If preflight red: a BLOCKED note with remediation is recorded and the run continues.

---

## E7b — Stubbed services  *(deps: E4; [parallel] with E7a once both are eligible)* — no live accounts
- **S7b.1** [logic] `AdService`/`IapService`/`LeaderboardService` interfaces + **no-op stubs** as default impl.
- **S7b.2** [integration] Inert UI hooks: revive, double-score, remove-ads, cosmetics, leaderboard (revived/doubled runs flagged out of leaderboard). Each hook calls its interface; default stub is no-op.

**Acceptance:** game runs fully on stubs; each hook invocation logs a call to its interface; the default impls are the no-op stubs (assert type); **no** live-account/network path is constructed (assert no plugin/singleton for AdMob/IAP is instantiated). Live wiring = documented manual follow-up.

---

## Out of autonomous scope (manual milestones, sequenced last)
iOS export (macOS+Xcode+Apple Developer) · live AdMob/IAP + Play Console publish · online
leaderboard OAuth · bespoke art + licensed music. Crunch stubs-and-continues at every
credential wall; none of these gate "done".

## Crunch termination
Done when E0–E6 acceptance criteria are green, E7a is either green or recorded-BLOCKED with
remediation, E7b is green on stubs, and a full-range council pass is clean. Credential-blocked
items recorded as BLOCKED do **not** prevent termination.
