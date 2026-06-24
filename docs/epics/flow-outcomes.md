# Epic E3 — Flow phase + outcomes

Implements design section: flow-outcomes. The verify phase: GO (or build-countdown expiry) →
water flows through the built network → the board resolves CLEARED / LEAK / BOMB on screen.

**The model already owns the flow logic** (E1: `GameState.step()`, `resolve()`, `Outcome`,
`is_cleared/is_bombed/is_leaking`, `score()`). E3 is the view/controller layer that drives it in
real time and shows the outcome. Model stays Node-free.

## Design decisions (assumptions — logged for council scrutiny)

- **Two small PURE model exposures** E3 needs (no Node deps added):
  - `GameState.outcome_now()` — make the existing private `_outcome_now()` public so the animator
    can check the CLEARED>BOMB>LEAK terminal each tick.
  - `GameState.score_route() -> Array[Vector2i]` — the cells on the shortest wet inlet→outlet route
    (BFS path reconstruction; the count version is `score()`). Feeds the scored-route highlight and
    the "highlighted route == model route" acceptance. NOTE (council NIT): `score()` counts
    channel-granular `(cell,channel)` nodes; `score_route()` returns cells — equal on MVP
    single-channel fixtures (STRAIGHT8: both 8); they could differ only if a route re-enters a cell
    on a second channel (needs branching → t-junctions, deferred). Assert `score()==route.size()`
    on MVP fixtures only.
- **FlowAnimator** (`scripts/view/flow_animator.gd`, Node): on a `Timer` (cosmetic water speed),
  calls `gs.step()` + `BoardView.refresh()` each tick; after each tick checks `gs.outcome_now()`;
  on a terminal outcome OR settle (`step()` false → final `outcome_now()`), stops the Timer and
  emits `outcome_resolved(outcome, score)`. Exposes `resolve_immediately()` for the **deterministic
  headless gate**: it **stops the Timer first**, then drives synchronous `gs.resolve()`, then the
  same emit (council RISK — never let the Timer and resolve() drive the same frontier concurrently).
- **GO seam** (council DIRECTIVE from E2): a HUD **GO** button AND build-countdown expiry both call
  `Main._start_flow()` from the **single existing `_process` block** — when `_build_remaining`
  crosses 0 in BUILD, call `_start_flow()` (no second `_process`). `_start_flow()` **guards
  `if _gs.phase == Phase.FLOW: return`** (council RISK — button-then-expiry / `_process` re-firing
  at 0 must not double-start). `_start_flow()` = `gs.go()` + `FlowAnimator.start()`.
- **Outcome display**: `Main._on_outcome(outcome, score)` (the shared handler for animator + headless):
  HUD outcome label ("CLEARED  score=N" / "LEAK" / "BOMB"); on CLEARED, `BoardView.highlight_route(gs.score_route())` (reuse Tile highlight); on BOMB, `BoardView.shake()`. Particles/geyser = E6 juice.
- Placement is already disabled in FLOW (model `place()` checks phase); the view need not re-guard.

## Sprint breakdown (model logic is TDD; view/animation is integration-gated)

- **S3.1** [logic+integration] model: `outcome_now()` public + `score_route()` (headless GUT:
  route cells of FX_STRAIGHT8 == the 8-cell line; control: a shortcut board's route is the short
  cells). Main GO path: HUD GO button + `_process` countdown-expiry seam → `_start_flow()`.
- **S3.2** [integration] `FlowAnimator` (Timer step + refresh; `resolve_immediately()`;
  `outcome_resolved` signal).
- **S3.3** [integration] outcome display: HUD outcome label + scored-route highlight (CLEARED) +
  shake (BOMB), via `Main._on_outcome`.

## Test strategy

- **Headless [logic] (GUT):** `score_route()` returns the exact route cells (FX_STRAIGHT8 → the
  8 line cells; failing control: a shortcut board returns the SHORT route's cells, not the long);
  `outcome_now()` matches `resolve()`'s result on fixtures. **Animator-loop coverage (closes the
  council gate-gap):** a headless test that manually drives `go()` then `while step(): outcome_now()`
  (mirrors the FlowAnimator tick loop WITHOUT the Timer) reaches the SAME outcome as `resolve()` —
  so the per-tick polling path is proven even though the real Timer cadence stays screenshot-only.
  (Flow/leak/bomb/clear logic itself is already E1-proven.)
- **[integration]** scripted Main (headless, console binary, stdout): for each fixture, build it,
  `_start_flow()` → `resolve_immediately()`, print outcome + score + the highlighted-route cells.
  FX_STRAIGHT8 → CLEARED score=8; FX_LEAK → LEAK; FX_BOMB_ADJ → BOMB; FX_OUTLET_VS_BOMB → CLEARED;
  highlighted route == `gs.score_route()`. Also assert countdown-expiry triggers `_start_flow()`.

## Proof (section: flow-outcomes)

Scripted Main (real `main.tscn` entry, headless) resolves each fixture to its correct outcome
(CLEARED score=8 / LEAK / BOMB / outlet-beats-bomb=CLEARED) and the displayed scored-route equals
the model route; GUT `score_route` control is red-able. Real entry point, failing controls,
positive liveness.
