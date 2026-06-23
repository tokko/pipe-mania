# Epic E1 — Core model (headless)

Implements design sections: core-model. Pure GDScript under `scripts/model/`, **no Node deps**
(testable headless via `tools/run-gate.ps1`). Spec: `docs/DESIGN.md`; constants + fixtures:
`docs/ROADMAP.md`.

## Design decisions (implementation assumptions — logged for council scrutiny)

- **Edges = direction bitmask.** `N=1, E=2, S=4, W=8`; `opposite(N)=S` etc. A piece's
  open-edge set is a mask. `straight`=`N|S` (rot 0) / `E|W` (rot 90); `bend`=`N|E`,`E|S`,`S|W`,`W|N`.
  `t-junction` is **deferred** (not generated in MVP).
- **Piece = `{type, rotation}`** → resolved open-edge mask via a small rotation map. The rotation
  toggle (E2) chooses `rotation`; default-off means rotation is fixed at the spawn orientation.
- **Graph = channel-aware `(cell, channel)` nodes** *(BLOCKER fix)*. Every placed pipe contributes
  node(s) to ONE shared graph that `step()`, leak eval, the wet-scoring BFS, AND the dry readout
  BFS all traverse — never a cell-level mask graph:
  - `straight` / `bend` → **one** node joining its (≤2) open edges.
  - `cross` → **two disjoint** nodes `(cell, NS)` (joins N↔S) and `(cell, EW)` (joins E↔W); they
    never link to each other, so no traversal can corner-cut through a cross.
  - **Connection** is at the channel level: edge `d` of cell `A` links only to the neighbor `B`'s
    channel that owns `opposite(d)`; flow/BFS enter a channel node and exit only via that
    channel's far edge.
- **Flow `step()`** — deterministic wavefront from the inlet over the channel graph. The frontier
  is an **insertion-ordered `Dictionary`** (fixed iteration order → reproducible runs). No
  wall-clock; the View calls `step()` on a timer, tests call it directly.
- **Leak** = the wet frontier has an open edge that does NOT continue flow — neighbor
  empty/blocked/channel-mismatched, **or the edge points off-board** — and it is **not** the
  outlet's inward edge. The inlet's exterior source edge is **never** evaluated as a leak. → fail.
- **Bomb** = wet frontier enters a cell orthogonally adjacent to a `bomb` → fail. **Clear checked
  before bomb** on the same step (`FX_OUTLET_VS_BOMB`).
- **Clear** = water reaches the `outlet` cell via its fixed inward edge.
- **Scoring** = BFS shortest path over the **wet channel graph** from inlet to outlet, counting
  pipe cells on that route; a shorter alternate route lowers the count. A separate **dry channel
  graph** query (same graph over placed-but-dry pipe) feeds E2's live readout. Because the graph
  is channel-aware, neither BFS can cut a corner through a `cross` (proven by `FX_CROSS_CORNER`).
- **BoardGen(seed, n):** place inlet/outlet on boundary; scatter `blocked`/`bomb` per
  `DifficultyConfig(n)` densities; **validate** a bomb-safe inlet→outlet corridor exists via
  cell-level BFS over open, non-bomb, bomb-non-adjacent cells; **retry ≤ 50** then **reduce hazard
  density** and retry. Seeded `RandomNumberGenerator`. **Accepted MVP scope-risk:** this proves a
  *corridor* exists, not that the *forced piece queue* can realize it — mitigated by free dry-pipe
  overwrite + 5-piece preview + generous early build time, not formally guaranteed.
- **DifficultyConfig(n):** the pinned table in `docs/ROADMAP.md` (exact formulas).

## Sprint breakdown (TDD: failing test first → implement → gate)

- **S1.1** `Board` (cell types, inlet/outlet, fixed edge dirs) + `GameState` wrapper (phase
  `BUILD`/`FLOW` + GO transition; phase lives in core so E3 needs no local flag).
- **S1.2** Seeded `BoardGen` + solvability validation (cell-level BFS; retry cap 50). Control: a
  hand-made unsolvable layout is rejected.
- **S1.3** Seeded piece queue (forced top, no skip/pick, 5-preview) + piece/orientation model +
  placement & dry-pipe overwrite. Control: overwriting **wet** pipe is rejected.
- **S1.4** Channel-aware `(cell, channel)` connection graph; `cross` = two disjoint channel nodes (no corner-cut).
- **S1.5a** Deterministic flow `step()` (water advances along connections).
- **S1.5b** Leak eval.
- **S1.5c** Bomb-adjacency + clear eval, outlet-reach checked before bomb.
- **S1.6** Shortest-route BFS scoring over the channel graph (wet) + dry-graph route-length query; discriminating control fixture `FX_CROSS_CORNER`.
- **S1.7** `DifficultyConfig(n)` per the pinned table.

## Test strategy

Headless GUT under `test/unit/`. **Exact-value assertions use the hand-authored fixtures**
(`FX_STRAIGHT8`, `FX_SHORTCUT`, `FX_LEAK`, `FX_BOMB_ADJ`, `FX_CROSSOVER`, `FX_CROSS_CORNER`,
`FX_UNCONNECTED`, `FX_OUTLET_VS_BOMB`) defined in `docs/ROADMAP.md`; fixtures are constructed as code helpers
(`test/fixtures.gd`) returning a `Board` + scripted placements. Seeds (1..200) drive the
`BoardGen` solvability property test. Every behavioral test pairs with a failing control.

## Proof (section: core-model)

`tools/run-gate.ps1` green, asserting every `core-model` acceptance criterion in
`crunch-state.json` (long path → 8; shortcut → 4, control → 10; leak/bomb fail + controls;
outlet-vs-bomb clears; crossover no-mix + no corner-cut (`FX_CROSS_CORNER`); forced-queue + wet-overwrite rejection; BoardGen
solvable across seeds; DifficultyConfig table at n=0/5/15), with an expected-vs-actual test-count
cross-check.
