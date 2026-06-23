# Pipe game — design spec & build plan (council-revised)

## Context

A shippable mobile **skill-puzzle**: a Pipe-Mania-style flow-puzzle with directional
inlet/outlet edges, bomb hazards, and a shortest-route scoring twist. Built **spec-driven
agentic** — Claude builds and verifies; the human reviews. Target: **Android-first** (iOS is
out of the autonomous scope — see Scope). This revision folds in a 6-reviewer council pass.

Working title "pipe-mania" (repo name). **Rename before shipping** — *Pipe Mania* / *Pipe Dream*
are trademarks. Ship name lives in a config constant from sprint 1.

## The hook

Each board is a two-phase round:

1. **Build phase** — a countdown (the difficulty clock). You place forced pipe pieces to route
   a path from inlet to outlet. No water yet: free to plan, overwrite, and go long. The goal
   is a **long, shortcut-free, bomb-safe route**.
2. **Flow phase** — tap **GO** (or the clock expires) and water runs your route to verify it.

> **Score (per cleared board) = length of the shortest inlet→outlet route through the wetted
> network.** Longer wins, so you build a long winding snake — but any shortcut/loop collapses
> the score to the shorter route. **Run score = Σ board scores.**

Separating "build long" (calm build phase) from "don't break it" (verify flow) is what makes
long paths worth attempting — resolving the council's central-tension blocker.

## Core loop (the spec)

**Board.** Grid of square cells; each is `open` (placeable), `blocked` (inert obstacle), or
`bomb` (lethal). One **inlet** and one **outlet** on the boundary, each with a fixed inward
edge direction. The generator guarantees a **bomb-safe inlet→outlet solution exists** (seeded,
validated at gen time — no unwinnable boards).

**Pieces.** A seeded queue. The player must play the **top** piece (can't pick type, can't
skip). **MVP piece set: `straight`, `bend`, `cross` (crossover = two independent non-mixing
channels, modeled as N–S and E–W edge-pairs).** `t-junction` (with fan-flow branching) is a
**post-MVP** addition — excluded from MVP to avoid undefined branch semantics. Preview shows
the next **~5** pieces (enough to plan a long route).

**Build phase.** A countdown runs. Tap an `open` cell to place the top piece; the next becomes
top. Dry pipe may be overwritten freely (no water yet). No fail state during build.

**Flow phase.** On GO / clock-expiry, water enters from the inlet and advances through
connected pipe (deterministic; pure verification — no placing during flow). Two adjacent cells
connect when both expose a matching open edge. The outlet accepts water arriving at its fixed
inward edge.

**Clear.** Water reaches the outlet via a connected route → board clear → load the next,
harder board.

**Fail (ends the run).** Water reaches an **open/dead end** — i.e. it must exit a cell through
an open edge into a cell with no matching pipe edge (leak/overflow) — **or** the water front
enters any pipe cell **orthogonally adjacent to a bomb** (detonation). If inlet/outlet never
connect, the verify flow leaks → 0 for that board, run ends.

**Evaluation order (council fix).** If the water front would simultaneously reach the outlet
and sit adjacent to a bomb, **reaching the outlet wins** (clear is checked before bomb).

**Scoring.** Shortest inlet→outlet route length over the **wetted** graph (BFS). Dry pipe and
non-carrying stubs don't count. Shortcuts collapse the score to the shorter route.

**Difficulty ramp (per board, all on pinned tunable curves with caps).** Build countdown ↓
(floored); bomb + blocked density ↑ (capped so a solution always fits); grid size ↑ **capped
so cells stay ≥ 44 dp** in portrait; piece mix harsher (fewer convenient straights/bends).
Verify-flow water speed is cosmetic (may rise for drama), not a difficulty knob.

## Locked decisions

| Decision | Locked value |
|---|---|
| Session | Endless score-chase; seeded procedural boards; one verify-fail ends the run |
| Flow model | **Two-phase: timed build phase → verify flow** (build clock is the only time pressure) |
| Scoring | Shortest inlet→outlet route length over wetted graph; longer, shortcut-free = higher |
| MVP pieces | straight, bend, cross (crossover); **t-junction deferred** |
| Rotation | No rotation by default; toggle reachable via an **in-run settings icon** |
| Bomb "touch" | Water front entering a pipe cell **orthogonally adjacent** to a bomb → fail; outlet-reach checked first |
| Overwrite | Dry pipe overwritable freely (build phase only) |
| Orientation | Portrait; **grid capped so cells stay ≥ 44 dp** |
| Determinism | `GameState` advances via an explicit `step()`/`tick`; **all RNG seeded** |
| Assets | Authored vector/shader art + **procedurally-synthesized SFX** (music deferred; "done" not gated on audio polish) |
| Engine | Godot 4, **Android-only** in the autonomous run |
| Scope | iOS **cut** (impossible on Windows host). Monetization / online leaderboard **stubbed behind interfaces**, fenced to M7b, not gating "done" |

**Minor defaults (vetoable):** single inlet + outlet per board · piece weights toward
straights/bends · local high score (online leaderboard stubbed) · Godot latest stable 4.x ·
sensible min Android API · colorblind-safe palette with shape/icon cues, not color alone.

## Tech decision: Godot 4

Agentic fit: direct Godot MCP tooling (`mcp__godot__*`) gives a real autonomous
build-run-read-debug loop; GDScript is small-surface; `godot-reviewer` + `/run-game` wired in.
iOS build/sign needs macOS + Xcode + Apple Developer — **deferred to a manual milestone**.

## Art & audio direction

Vibrant cartoony plumbing world, **readability first**. Authored vector/shader art (Godot
`_draw` + shaders), portrait. Cell types and water/dry-pipe distinguished by **shape/icon +
contrast, not color alone** (colorblind-safe).

- **Feedback:** placement snap/bounce; valid-cell highlight on **touch-down**; invalid tap =
  shake + buzz; build-clock urgency cue near zero; bomb cells pulse a warning glow within a
  defined proximity; on flow: pipes visibly fill, detonation = screen-shake + splash,
  board-clear = water geyser + **scored-route highlight** + score pop. Haptics on place / fail
  / clear.
- **Audio:** procedurally-synthesized SFX (bubble pops, valve squeaks, glug, clear-burst, bomb
  whump). Music deferred (agent can't source CC0 audio reliably) — left as a clean swap point.

## Scoring legibility (council fix)

The shortest-route rule is non-obvious, so it must be taught and shown: a one-board tutorial; a
**live per-board route-length readout** during build; on clear, **animate the scored shortest
route** so the player sees exactly what counted (and why a shortcut hurt). Show both per-board
and run-total score.

## Architecture (testability-first)

Pure logic split from rendering so the core is verifiable headless:

- `GameState` / `Board` (plain GDScript, **no Node deps**): grid, cell types, seeded piece
  queue, placement + overwrite, edge-connection graph (crossover = two channel-pairs),
  **deterministic `step()`**, leak/bomb/clear eval, **shortest-route BFS scoring**,
  `DifficultyConfig` (pinned params, no scattered magic numbers).
- `BoardGen` (seeded): produces boards + **validates a bomb-safe solution exists**.
- `Run` (autoload/singleton): endless-session controller — phase state machine (build↔flow),
  board-clear → escalate → next, run score, run-end.
- `BoardView` + `Tile`: render grid + pipes, tap-to-place, rotation input; **tiles pooled at
  board-load**, not during play. Communicates via **signals**, not `_process` polling.
- `FlowAnimator`: drives the verify-flow animation off `GameState.step()` results.
- `SaveStore`: high score + settings persistence (single boundary; HUD never touches FS).
- `HUD`: build countdown, next-piece preview (~5), live route length, per-board + run score,
  clear/fail + restart, in-run settings (rotation, audio, haptics).
- Monetization/leaderboard behind named interfaces (`AdService`, `IapService`,
  `LeaderboardService`) with no-op stubs as the default impl.

## Build milestones (each independently verifiable)

1. **Core model (headless)** — grid, seeded queue, connection graph (incl. crossover),
   deterministic `step()`, leak/bomb/clear eval, shortest-route scoring, `DifficultyConfig`,
   seeded `BoardGen` + solvability validation. *Verify:* GUT (see below).
2. **Board render + build-phase placement** wired to the model (+ rotation toggle).
3. **Flow phase + verify animation** driven by `step()`; clear/fail outcomes.
4. **Endless run loop** — phase state machine, board-clear → escalated next, run-score sum,
   fail → run-end + high-score persistence, restart.
5. **Procedural difficulty curve** — tune `DifficultyConfig` ramp (build time / hazards / size
   cap / piece mix); first-board onboarding/tutorial.
6. **Juice** — vector/shader art, synthesized SFX, animations, haptics, particles, bomb shake,
   scored-route highlight, colorblind cues.
7a. **Android export** (no credentials) — keystore/SDK/NDK preflight, build a runnable APK,
   store-listing scaffold, trademark-safe name.
7b. **Stubbed services** — `Ad/Iap/Leaderboard` interfaces + no-op stubs + UI hooks (revive /
   remove-ads / cosmetics / leaderboard), wired but inert; live wiring needs human accounts.

iOS, live AdMob/IAP, online leaderboard, bespoke art/music = **manual milestones after the run**.

## Monetization — F2P hybrid (stubbed this run, live later)

Rewarded video (revive / double-score / daily cosmetic — flagged out of leaderboard for
fairness), "remove ads" IAP, cosmetic IAP, sparing interstitials. No pay-to-win. Built behind
the service interfaces above; live integration (Poing AdMob plugin etc.) blocks on accounts.

## Verification (behavioral proof — CLAUDE.md §4)

Deterministic via seeded RNG + `step()`. Each test starts from empty state, has a **failing
control**, exercises the real artifact, asserts positive liveness, and cross-checks
expected-vs-actual test count.

- **Logic (headless GUT, primary):** shortest-route long path scores its full length;
  **shortcut path scores the SHORT length and the control asserts the exact short value (not
  merely "not long")**; leak fails (control: a connected path must NOT leak); bomb-adjacency
  fails (control: a non-adjacent bomb must NOT fail); overflow board **scores 0 AND ends the
  run**; **run-score = Σ across a scripted multi-board run**; crossover channels **don't mix**
  (control: perpendicular inputs stay separate); forced-queue (can't skip/pick) + overwrite;
  `BoardGen` always emits a solvable, bomb-safe board across many seeds; `DifficultyConfig`
  ramp produces the expected concrete values per board index.
- **Integration:** `mcp__godot__run_project` + `get_debug_output` — a **fixed-seed** scripted
  round logs a board-clear with a **known expected score** to assert.
- **On-device smoke:** android-emulator MCP on a pre-provisioned AVD — launch APK, play a
  **fixed-seed** board, screenshot a real board-clear (positive liveness).

## Execution pipeline (in progress)

1. ✅ **Council-revise the spec** — this document.
2. **Decompose into epics + sprints** aligned to milestones 1–7b; scaffolding (Godot 4 +
   project-skeleton) is sprint 1; kanban `state.json` is source of truth.
3. **Council-review the decomposition** — fix structural/dependency-ordering gaps.
4. **Emit `docs/ROADMAP.md`** (crunch-consumable): epics, per-epic behavioral acceptance
   criteria, dependency order.
5. **Begin `/crunch`** — autonomous TDD sprints, harden per epic, continue across turns until
   acceptance criteria are met with a clean council. Credential/Mac-blocked work is
   stubbed-and-continued, never halted.
