# Pipe Mania / Aqueduct

## Start here

- Read `docs/HANDOFF.md` before changing anything. It is the current state and resume point.
- Treat the shipped code and tests as the behavioral source of truth. `docs/DESIGN.md` and `docs/ROADMAP.md` are the original plan and contain superseded details.
- In particular, do not reintroduce manual rotation, haptics, or the fixed tutorial board. Pieces are dealt pre-oriented, and the flow countdown starts after the first placement.
- `.auto-sprint-board/` and `.claude/council/` are ignored local artifacts from the earlier Claude workflow. Do not restore, convert, or commit them unless the user asks.

## Project map

- Godot 4.6.2, portrait Android-first game. The shipped entry scene is `scenes/main.tscn`.
- `scripts/main.gd` controls a run; `scripts/screen_controller.gd` controls splash/menu/game/run-over navigation.
- `scripts/model/` is pure game logic. Keep it independent of `Node` and rendering code.
- `scripts/view/` owns rendering and input. Views communicate with controllers through signals.
- `PIPE_TEST` selects the scripted integration path in `scripts/main.gd`. Preserve the separation between that path and the shipped UI path.
- Live ads, billing, and online leaderboards remain account-gated. Keep the stub services unless the user supplies the required accounts/plugins and asks for live wiring; see `docs/MONETIZATION_SETUP.md`.

## Working rules

- Use PowerShell commands. If Git reports dubious ownership, use command-scoped `git -c safe.directory='D:/claude projects/pipe-mania' ...`; do not change global Git config.
- Inspect `git status` first and preserve unrelated or user-authored changes.
- Do not commit unless the user asks.
- Make the smallest change that satisfies the request. Do not refactor adjacent code.
- For behavior changes and bug fixes, add or update the focused test first, prove it fails for the intended reason, then implement the minimum fix.
- Do not edit generated `.godot/`, `.import/`, `.gut_src/`, `build/`, or `.tmp/` content.

## Verification

- Run the full headless gate from the repository root:

  ```powershell
  & '.\tools\run-gate.ps1'
  ```

- A valid green run exits `0`, has positive passing-test and assertion counts, and reports exactly one intentional pending test: `test/unit/test_failing_control.gd`.
- When changing the gate or test harness, temporarily set `RUN_CONTROL := true` in that test and confirm the gate goes red. Restore it to `false`, then rerun the green gate.
- Headless tests do not prove shipped UI, touch behavior, readability, or game feel. For those changes, exercise the normal non-`PIPE_TEST` entry point and use visible desktop or installed-APK evidence.
- For Android work, run `tools/android-preflight.ps1` before exporting. Keep `gradle_build/use_gradle_build=false` until the live plugins and their required toolchain are intentionally introduced.

## Known traps

- Never name a `Node` method after a native method such as `rotate()`; this project previously hung on that collision.
- Add explicit types when assigning values returned from untyped game-state or layout calls.
- Android touch is emulated as a mouse click. `BoardView` intentionally handles only the mouse press; handling both sources places two pieces.
- Any teardown path must reset the same clock and view state as `_mount_board()` before freeing nodes.
- In negative JSON tests, use valid JSON with the wrong shape. Raw invalid JSON logs an error that PowerShell promotes to a gate failure.
- If Godot cannot replace an APK under this path with spaces, export to a no-space path such as `C:\Temp\aqueduct.apk` and install from there.
