# Epic E7a — Android export (preflight + config; build parked)

Implements design section: android-export. Keystore/SDK/NDK preflight → build a runnable APK →
store-listing scaffold → trademark-safe name. **Credential/SDK-gated.** Acceptance: #1 "preflight
fails loudly with remediation and marks BLOCKED if SDK/NDK/keystore/AVD absent", #2 "debug APK
builds headless IF preflight green", #3 "AVD smoke … OR is recorded BLOCKED".

**SECTION STATUS = PARKED, not proof-passing (council ruling).** The APK is the section's primary
deliverable and it was never produced (export templates absent). Acceptance #2's antecedent is false,
but an unexecuted deliverable is NOT a satisfied one — marking the section proof-passing would be
self-certification. So: E7a BUILDS the autonomous-provable artifacts (the preflight + export config +
scaffold), the preflight's BLOCKED detection (#1) is genuinely proven, and the **APK build + AVD
smoke are recorded in `parked[]` (HIGH) with remediation.** This makes the run's terminal
`drained-but-blocked` (loud) — the honest outcome: design implemented to the autonomous ceiling,
device build surfaced as a human task. (Per design, the Android device build is a "manual milestone
after the run".)

**Machine state (preflighted 2026-06-24):** Android SDK partially present (cmdline-tools,
build-tools, emulator, platform-tools/adb) + JDK keytool present, BUT **Godot 4.6.2 Android export
templates are ABSENT** and Godot's editor Android SDK/JDK paths + a debug keystore are not
configured. So the headless APK export **cannot run** → the autonomous-provable slice is the
**preflight that detects this and parks loudly with remediation**; the APK build + AVD smoke are
**PARKED** (acceptance #1/#3 satisfied via the BLOCKED path; #2's antecedent is false).

## Design decisions (assumptions — logged for council scrutiny)

- **`tools/android-preflight.ps1`** — the autonomous proof for acceptance #1. Checks, each pass/fail
  with a remediation line: Godot Android export templates (the hard blocker), Android SDK path, **the
  Godot editor's configured `export/android/android_sdk_path` + `java_sdk_path` (council RISK — SDK
  present on disk ≠ Godot able to use it)**, NDK (**both `ANDROID_NDK_HOME` AND the SDK's `ndk/`
  subdir — council NIT: NDK may live inside the SDK tree**), JDK/keytool, debug keystore. Prints a
  per-check report + overall `PREFLIGHT: GREEN` (exit 0) or `PREFLIGHT: BLOCKED` (exit 2) with exact
  remediation. On this machine: BLOCKED (templates absent + editor paths unconfigured).
- **`export_presets.cfg`** — a minimal Android preset (preset.0) using `Config.GAME_NAME` ("Aqueduct")
  + a placeholder package `org.aqueduct.game`. **It is a STARTING-POINT SCAFFOLD, not an
  export-validated file (council RISK):** Godot validates preset fields only at export time, so the
  human will regenerate/validate it through the editor when provisioning. The provable claim is only
  "a named Android preset scaffold exists", not "this exports".
- **`docs/store-listing.md`** — store-listing scaffold (title=GAME_NAME, short/long description,
  category, content rating TODO, screenshots TODO) — text scaffold, not a submission.
- **PARKED (loud, with remediation):** the actual signed/debug APK build + the AVD board-clear smoke
  test. They need a human to install Godot's Android export templates, set the editor Android SDK +
  JDK paths, and generate a debug keystore — then `tools/android-preflight.ps1` goes GREEN and the
  build can run. Surfaced in the final crunch report's parked list. (Crunch law: park at credential
  walls, never halt.)

## Sprint breakdown

- **E7a.1** [tooling] `tools/android-preflight.ps1` — toolchain checks + remediation + GREEN/BLOCKED
  verdict + exit code. Proof: run it → reports BLOCKED (export templates absent) with remediation.
- **E7a.2** [config] `export_presets.cfg` (Android preset, GAME_NAME, package) + `docs/store-listing.md`
  scaffold. APK build + AVD smoke PARKED (preflight red).

## Test strategy

- **[tooling] proof:** run `tools/android-preflight.ps1` inline (out-of-sandbox) → it exits non-zero
  with `PREFLIGHT: BLOCKED` + names the missing pieces + remediation (acceptance #1). A GREEN run on
  a properly-provisioned machine would then allow the build (acceptance #2) — not reproducible here,
  recorded as PARKED (acceptance #3).
- **config:** assert `export_presets.cfg` exists + contains an `android` platform preset + the safe
  name; `docs/store-listing.md` exists with the title from `Config.GAME_NAME`.

## Proof (section: android-export) — PARKED, not proof-passing

The autonomous-provable part is proven: `tools/android-preflight.ps1` runs and correctly reports
`BLOCKED` with per-check remediation (acceptance #1); `export_presets.cfg` + `docs/store-listing.md`
exist with the trademark-safe name. But the **APK (the section's deliverable) is unbuilt** → the
section is **PARKED (HIGH)**, recorded in `parked[]` with remediation (install Godot 4.6.2 Android
export templates; set editor Android SDK + JDK paths; generate a debug keystore; re-run the preflight
→ GREEN → `godot --headless --export-debug Android out.apk`; then the AVD board-clear smoke). This
parks the run at `drained-but-blocked` — the honest terminal, NOT `done`.

## Notes

- No extension skill — E7a adds no `add-<concept>` extensible variants.
- This is the design's "manual milestone after the run" boundary for the actual device build.
