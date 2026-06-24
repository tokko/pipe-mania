# Epic E4 — Endless run loop

Implements design section: endless-run. The score-chase session: board-clear → escalate
difficulty → next board, run-score = Σ board scores; a verify-fail (LEAK/BOMB) ends the run →
high-score persistence + restart. Driven by E3's `FlowAnimator.outcome_resolved`.

## Design decisions (assumptions — logged for council scrutiny)

- **`Run` is a pure Node-free model** (`scripts/model/run.gd`, RefCounted), GUT-testable — NOT a
  Node autoload. The design doc says "autoload singleton"; a plain object owned by `Main` is
  functionally the single run instance but headless-testable. Owns: `run_seed`, `board_index`,
  `run_score`, `high_score`, `over`.
  - `on_clear(score)` → `run_score += score; board_index += 1`.
  - `on_fail()` → `over = true; high_score = max(high_score, run_score)`.
  - `next_board()` → `var c = Difficulty.config(board_index)`;
    `BoardGen.generate(run_seed + board_index, c.grid_w, c.grid_h, c.bombs, c.blocked)` +
    `PieceQueue.new(run_seed + board_index, c.weights)` → `GameState.new(board, queue)`.
    Deterministic per `run_seed`; **also wires `c.weights` into the queue — the per-board piece
    mix Main currently drops** (today `GameState.new(b)` defaults to `PieceQueue.new(0)`).
  - `restart()` → `board_index = 0; run_score = 0; over = false` (KEEP `high_score`).
- **`SaveStore`** (`scripts/save_store.gd`, RefCounted): high score persisted as JSON in
  `user://highscore.json`. `load_high() -> int` (0 if absent/corrupt); `save_high(int)`.
  FileAccess works headless → GUT round-trip.
- **Main routes through Run from board 0** (single production board-creation site): `_start_game`
  becomes `_run = Run.new(seed); _run.high_score = SaveStore.load_high()` then `_mount_board(...)`.
  The `_on_outcome` handler (E3) gains: CLEARED → `_run.on_clear(score)` then `_mount_board` for
  `_run.next_board()`; else → `_run.on_fail(); SaveStore.save_high(_run.high_score)`; show run-end
  + restart. HUD shows run-score + high-score. (Scripted fixtures keep building boards directly.)
- **`_mount_board(gs)` — the single teardown-safe board-mount path** (council BLOCKERs): used by
  both `_start_game` and the reload-on-clear branch. It (1) frees the existing `_bv`/`_hud` if
  present (`queue_free()`) so ghost nodes with live `cell_tapped`/`go_pressed`/`rotate_pressed`
  connections don't accumulate → no duplicate input/render; (2) builds + wires a fresh
  `BoardView`/`HUD` for `gs`; (3) **resets `_build_remaining = float(config.build_seconds)` +
  `_hud.set_countdown(...)`** so the new build phase counts down (else `_process` would fire
  `_start_flow` immediately on the new board). The `_highlighted` reset is moot once `_bv` is
  rebuilt, but `BoardView.setup()` clearing it (S3 harden) stays the safety net.
- **`FlowAnimator.setup()` stops any live Timer** (council RISK): defensive — a reload re-points
  `_gs`/`_bv`; if a prior Timer were still live, the next `start()` must not double-drive.

## Sprint breakdown

- **S4.1** [logic] `Run` model: `on_clear`/`on_fail`/`next_board`/`restart` + Σ run-score +
  board-index escalation + `over`. GUT (test-first).
- **S4.2** [logic] `SaveStore` high-score JSON persistence in `user://`. GUT round-trip (test-first).
- **S4.3** [integration] wire `Main` ↔ `Run` + `SaveStore`: `outcome_resolved` → Run → on CLEARED
  rebuild view/HUD for `next_board`; on fail → run-end + save + restart; HUD run/high score.

## Test strategy

- **Headless [logic] (GUT):** a synthetic 3-board run — `on_clear(3); on_clear(5); on_clear(2)` →
  `run_score == 10`, `board_index == 3` (control: a run with one `on_fail` partway stops summing).
  `on_fail()` sets `over` + lifts `high_score` (control: a smaller run does NOT lower high_score).
  `restart()` zeroes index+score, keeps high_score. `next_board()` determinism: same `run_seed`
  yields the same board dims/seed per index; `board_index` selects `Difficulty.config(index)` (grid
  grows with index). `SaveStore`: save 42 → fresh load returns 42; absent file → 0.
- **[integration]** scripted Main (headless): feed three CLEARED outcomes via the real
  `_on_outcome` path → assert RUN_SCORE = Σ + INDEX increments + **board RELOADED each time
  (`_gs.board.width`/`height` match `Difficulty.config(board_index)` — council RISK: proves the
  rebuild, not just the counter)**; feed a LEAK → RUN_OVER true + run-end label + HIGH saved;
  restart → INDEX=0/SCORE=0, HIGH retained.

## Proof (section: endless-run)

Scripted Main (real entry, headless) asserts the 4 acceptance criteria: 3-board run logs
run-score = exact Σ of per-board scores; board index increments after a clear; high score survives
a `SaveStore` reload; restart resets index→0 and score→0. Real entry point, failing controls
(fail-stops-summing; smaller-run-doesn't-lower-high), positive liveness.

## Notes

- **No extension skill** — E4 adds no `add-<concept>` extensible variants (the extensible concepts
  are pieces (t-junction, deferred) and board generators, not the run loop).
- Difficulty escalation reuses E1's pinned `Difficulty.config(n)`; `board_index` IS `n`.
