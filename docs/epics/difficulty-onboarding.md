# Epic E5 — Difficulty curve + onboarding

Implements design section: difficulty-onboarding. The procedural ramp is **already pinned and
swept** (E1/S1.7: `Difficulty.config(n)` exact table at n=0/5/15 + `build_seconds` monotonic
non-increasing for n=1..30 + grids ≤ cap for n=0..30) and the **≥44dp-at-cap** guarantee is
proven (E2 rendering proof + grid_layout floor control). The live route-length **readout** (E2 HUD)
and the **scored-route highlight** on clear (E3) are built and behaviorally proven.

So E5 adds **no new ramp code** — its net-new deliverable is the **one-board onboarding tutorial**
that teaches the non-obvious shortest-route scoring. Acceptance #1/#2/#4 are satisfied by existing
tests; #3 (FX_TUTORIAL) + the onboarding hook are this epic.

## Design decisions (assumptions — logged for council scrutiny)

- **`Run.tutorial_board()`** — a deterministic, hand-authored *simple* board (small grid, no bombs,
  a short inlet→outlet corridor) the player can obviously complete; the vehicle for teaching.
  Deterministic = same board every call (fixed layout).
- **Tutorial = the board-0 SUBSTITUTE on a fresh run (council BLOCKER fix).** On a fresh run
  (tutorial not seen), the tutorial board *is* `board_index 0` — it replaces the procedural
  `config(0)` board. Clearing it runs the normal `on_clear` (banks its score, `board_index→1`), so
  the run continues into `config(1)`, `config(2)`, … exactly like any board — NO special "new run"
  path, no skipped ramp step (the tutorial occupies the config(0)-tier slot). Its build timer is
  `config(0).build_seconds` (board_index 0 → `_mount_board` already pulls config(0) = 25s, generous
  for learning). Once `tutorial_seen`, a fresh run's board 0 is procedural `config(0)` as normal.
- **`SaveStore` gains a `tutorial_seen` flag** in the SAME `user://highscore.json`. Refactor to
  read-modify-write a dict (`_load()->Dictionary` / `_save(Dictionary)`); **`save_high` is rewritten
  to the RMW pattern too** (load dict, set "high", save) so it and `save_tutorial_seen` don't clobber
  each other. `load_high/save_high` keep identical observable behavior (the 4 existing tests stay
  green); add `load_tutorial_seen` (default false) / `save_tutorial_seen`.
- **Onboarding hook in Main**: on `_start_game`, if `!SaveStore.load_tutorial_seen()`, build the Run
  but mount `Run.tutorial_board()` as board 0 and show a HUD **tutorial banner** (rules: build a long
  inlet→outlet path, longer shortcut-free = more points, avoid bombs, tap GO). On the first GO,
  `SaveStore.save_tutorial_seen(true)` + clear the banner.
- **Acceptance #1/#2 are owned by the EXISTING `test/unit/test_difficulty.gd`** (table n0/n5/n15 +
  monotonic 1..30 + caps 0..30), which the gate runs — the section's `proof_cmd` references it. E5
  does NOT re-assert or duplicate it (a copy would drift; calling the same file proves nothing new) —
  it simply *depends* on that file staying green. (Council RISK: this dependency is the proof, not a
  redundant re-assert.)
- **"visible in screenshot" (acceptance #4)** is proven behaviorally (route-readout value updates +
  highlight cells == model route — E2/E3 markers). The literal screenshot is the one MANUAL/deferred
  item: **a human launches the game, plays one board, and confirms the live route number changes
  during build and the winning route highlights on clear** — surfaced in the final crunch report's
  parked-for-human list (named owner: the human running the project), not gating autonomous `done`.

## Sprint breakdown

- **E5.1** [logic] `Run.tutorial_board()` (deterministic simple board) + `SaveStore` dict refactor
  with `tutorial_seen` accessors. GUT (test-first): tutorial board is deterministic + a known
  solution clears it (control: partial build does NOT clear); `tutorial_seen` round-trips AND does
  not clobber `high` (control: save_high(50) → save_tutorial_seen(true) → load_high()==50). (Ramp
  acceptance #1/#2 stays owned by the existing test_difficulty.gd — not re-asserted here.)
- **E5.2** [integration] onboarding hook in Main + HUD tutorial banner. Scripted proof: fresh run
  (tutorial_seen=false) → TUTORIAL_SHOWN=true + board==tutorial dims; first GO sets the flag; a
  second `_start_game` with the flag set → TUTORIAL_SHOWN=false + procedural board 0.

## Test strategy

- **Headless [logic] (GUT):** ramp acceptance #1/#2 is already owned by the existing test_difficulty
  (table n0/n5/n15, monotonic 1..30, caps 0..30) — the gate runs it; E5 depends on it, does NOT
  duplicate it. New in E5.1: `tutorial_board()` determinism + completability (known solution →
  CLEARED; control: incomplete → not CLEARED); `SaveStore` tutorial_seen round-trip + non-clobber of
  high (control: save_high then save_tutorial_seen then load_high == original).
- **[integration]** scripted Main: TUTORIAL_SHOWN + board-is-tutorial on fresh run; flag-set after
  GO; procedural board 0 + no banner once seen.

## Proof (section: difficulty-onboarding)

`tools/run-gate.ps1` (difficulty sweep n=0..30 + tutorial completable/deterministic + SaveStore
flag) green, AND scripted Main shows the first-run tutorial (TUTORIAL_SHOWN=true, tutorial board)
then skips it once seen. Route-readout + scored-route highlight already proven (E2/E3); the literal
screenshot is the one manual/deferred tier item. Real entry point, failing controls, positive liveness.

## Notes

- No extension skill — E5 adds no `add-<concept>` extensible variants.
- No new ramp code: the pinned `Difficulty.config(n)` (E1) is the curve; E5 only validates + teaches.
