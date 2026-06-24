# Epic E7b — Stubbed services (Ad / IAP / Leaderboard)

Implements design section: stubbed-services. Monetization + leaderboard behind **named interfaces
with no-op stubs as the default impl** (design). Wired but inert: live integration (AdMob plugin,
IAP, online leaderboard OAuth) needs human accounts → that's the deferred manual milestone; E7b is
the **fully autonomous-provable** interface + stub + UI-hook layer.

Acceptance: #1 "game runs fully on no-op service stubs"; #2 "each UI hook invocation logs a call to
its interface"; #3 "no live-account/network path (AdMob/IAP/leaderboard) is constructed".

## Design decisions (assumptions — logged for council scrutiny)

- **`scripts/services.gd` (Services autoload)** holds three no-op stub services (inner classes —
  Simplicity; they're 3 fixed services, NOT an open `add-<service>` family, so no extension skill):
  - `AdServiceStub` — `show_rewarded(kind)`, `show_interstitial()`
  - `IapServiceStub` — `purchase_remove_ads()`, `purchase_cosmetic(id)`
  - `LeaderboardServiceStub` — `submit_score(score)`
  Each method ONLY records `last_call` (a string) and returns — no AdMob/IAP SDK, no HTTP, no account
  path (satisfies #3 structurally: the only impls that exist are the stubs). `Services.ad/iap/
  leaderboard` expose the stub instances as the default impl.
- **UI hooks in HUD → Main → Services:** HUD buttons `Revive` / `Remove Ads` / `Leaderboard` emit
  signals; Main routes them: Revive → `Services.ad.show_rewarded("revive")`; Remove Ads →
  `Services.iap.purchase_remove_ads()`; Leaderboard → `Services.leaderboard.submit_score(run_score)`.
  (Design's rewarded-revive / remove-ads-IAP / leaderboard-submit, inert.)
- **Live wiring is the deferred manual milestone** (needs accounts) — NOT built; logged, not parked
  as a blocker (the design fences it out of the autonomous run; it does not gate this section's done).

## Sprint breakdown

- **E7b.1** [logic] `scripts/services.gd` (3 stub services + Services autoload). GUT (test-first):
  each stub method records its `last_call`; a fresh stub's `last_call` is empty (control); no method
  returns/constructs anything live (no-op).
- **E7b.2** [integration] HUD `Revive`/`Remove Ads`/`Leaderboard` buttons + signals → Main → Services.
  Scripted: invoking each hook sets the matching service's `last_call`; the game (real scene) runs on
  the stubs without crashing; `Services.ad/iap/leaderboard` are the Stub types (no live impl).

## Test strategy

- **Headless [logic] (GUT):** `AdServiceStub.show_rewarded("revive")` → `last_call=="rewarded:revive"`;
  `IapServiceStub.purchase_remove_ads()` → `"remove_ads"`; `LeaderboardServiceStub.submit_score(7)` →
  `"submit:7"`; fresh stub `last_call==""` (control). Stubs are plain RefCounted, no network deps.
- **[integration]** scripted Main: fire each HUD hook → assert `Services.<svc>.last_call`; assert
  `Services.ad` is `AdServiceStub` etc. (no live path); the scripted run itself proves the game boots
  + plays on the stubs (acceptance #1).

## Proof (section: stubbed-services)

`tools/run-gate.ps1` (stub call-recording + control) green, AND scripted Main: each UI hook logs a
call to its interface (HOOK_REVIVE=rewarded:revive / HOOK_REMOVEADS=remove_ads / HOOK_LB=submit:N)
and the game runs on the stubs (no crash). Acceptance #3 "no live path" is proven STRUCTURALLY
(council): `services.gd` contains no network/SDK construct (no `HTTPRequest`, no `http`, no AdMob/IAP
plugin) — the stub methods only set `last_call: String`. (Type-`is` checks on inner classes are
gotcha-prone across scripts, so identity is proven by behavior + the structural absence, not `is`.)
Real entry point, failing control (fresh last_call empty), positive liveness.

## Notes

- No extension skill — 3 fixed services, not an open `add-<concept>` family.
- Live AdMob/IAP/leaderboard wiring = manual milestone after the run (needs accounts).
