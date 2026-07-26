# Google Play Publishing Implementation Plan

> **For Codex workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish Aqueduct through a new personal Google Play account after a genuine closed test, with production AdMob and no fake purchase flow.

**Architecture:** Retain the existing rewarded-revive/interstitial STUB/TEST/LIVE seam. Remove the reachable fake `Remove Ads` entitlement instead of adding deferred Play Billing. Add a separate Gradle-backed `Android Live` signed AAB preset; do not repurpose the existing `Android` or `Android Test` presets.

**Tech Stack:** Godot 4.6.2, GDScript, Poing Studios AdMob v4.3.1, Google UMP/AdMob, Android Gradle export, Google Play Console, PowerShell.

---

## Execution hold

- [ ] Do not perform implementation, account setup, Reddit recruitment, release uploads, or external publishing before **00:00 Europe/Stockholm on 2026-07-18**. Saving this plan is the sole action authorized now.
- [ ] At midnight, reread `docs/HANDOFF.md` and inspect `git -c safe.directory='D:/claude projects/pipe-mania' status --short`. This worktree is deliberately dirty with AdMob work; preserve every pre-existing change.
- [ ] Before implementation, create or switch to an isolated `feature/` branch. Do not commit unless the user asks.

## File map

- Modify: `scripts/services.gd`, `scripts/main.gd`, `scripts/screen_controller.gd`, `scripts/view/settings_view.gd`, `scripts/settings.gd`, `scripts/save_store.gd` — remove the fake `Remove Ads` service/UI/entitlement only.
- Modify: focused `test/unit/test_*` files that name `ads_removed`, `purchase_remove_ads`, or fake-purchase markers.
- Modify: `export_presets.cfg`, `tools/android-preflight.ps1`, `tools/export-ads-build.ps1` — add a separate signed `Android Live` AAB path.
- Modify: `docs/MONETIZATION_SETUP.md`, `docs/store-listing.md`, `docs/HANDOFF.md` — record final release facts only.
- Create: `docs/release/reddit-tester-recruitment.md` — approved recruitment copy and tester brief after the closed-test link exists.

### Task 1: Remove the fake Remove Ads offer

**Files:** `scripts/services.gd`, `scripts/main.gd`, `scripts/screen_controller.gd`, `scripts/view/settings_view.gd`, `scripts/settings.gd`, `scripts/save_store.gd`, and focused `test/unit` files.

- [ ] Change the focused Settings test first: for STUB, TEST, and LIVE, Settings must contain only `Audio: ON`/`Audio: OFF` and `Back`; it must contain no `Remove Ads` text or signal.
- [ ] Run the focused test and confirm it fails because the current Settings screen exposes `Remove Ads`.

```powershell
& '.\tools\run-gate.ps1' -TestPath 'res://test/unit/test_settings_view.gd'
```

- [ ] Delete `IapServiceStub`, `Services.iap`, the `purchase_succeeded` hookup, `purchase_remove_ads`, `ads_removed` persistence, SettingsView’s remove-ads argument/signal/button, and the scripted fake-purchase/interstitial-suppression markers. A due interstitial must always call the ad service; do not add Google Play Billing.
- [ ] Update direct callers and delete only tests for the removed fake contract. Existing save JSON may retain unknown keys; do not migrate or erase user data.
- [ ] Run the complete gate and a normal non-`PIPE_TEST` Settings smoke. Confirm only Audio and Back are present.

```powershell
& '.\tools\run-gate.ps1'
```

Expected: exit `0`, positive passing-test/assertion counts, exactly one intentional pending control (`test/unit/test_failing_control.gd`), and no `SCRIPT ERROR`.

### Task 2: Establish the permanent account and app identity

- [ ] The human owner creates and verifies a new Personal Play Console account. Do not provide Codex with credentials, payment data, identity documents, keystore passwords, or account tokens.
- [ ] Trademark-check and finalize the game name before the first upload. Confirm `org.aqueduct.game` is the permanent package identity; it cannot be reused after a Play upload. If changed, update the relevant Godot/project/preset/listing fields in one focused change and rerun the gate.
- [ ] Create the AdMob Android app only after package identity is final. Create exactly one Rewarded unit and one Interstitial unit; configure UMP messaging for EEA, UK, and Switzerland; publish `app-ads.txt`; register real development devices as test devices.
- [ ] Publish a public, non-PDF HTTPS privacy policy that accurately covers the local game saves and the Mobile Ads/UMP SDK data practices, retention/contact route, and named publisher. Put the link both in Play Console and in an in-app Settings/About control; complete Data Safety from the actual SDK behaviour, not merely the local game code.

### Task 3: Add and prove the Android Live AAB path

**Files:** `export_presets.cfg`, `tools/android-preflight.ps1`, `tools/export-ads-build.ps1`, `scripts/monetization_config.gd`, `docs/MONETIZATION_SETUP.md`.

- [ ] Add Live preflight assertions first. `-Target Live` must require: preset `Android Live`; Gradle; only `admob_live`; arm64; an AAB release export; a valid non-demo App ID/rewarded/interstitial triple; a real release keystore and alias outside Git; and a version code higher than every uploaded Play build.
- [ ] Prove Live preflight fails while IDs/signing/preset are absent; keep the existing Android and Android Test checks green and unchanged.

```powershell
& '.\tools\android-preflight.ps1' -Target Live
& '.\tools\android-preflight.ps1' -Target Test
```

- [ ] Create `Android Live` as a third preset. It uses Gradle, `custom_features="admob_live"`, AAB export, release signing, arm64, and an explicit/effective target SDK 36. Do not modify `Android` (stub/no ads) or `Android Test` (debug APK, `admob_test`, Google demo IDs).
- [ ] Add a `Live` branch to `tools/export-ads-build.ps1`: set `AQUEDUCT_ADS_EXPORT_TARGET=Live` only for the export process, call the release export, and emit `C:\Temp\aqueduct-live.aab`. Preserve Test’s debug APK route.
- [ ] Add the human-provided canonical production AdMob IDs only after the account actions are complete. Never commit signing passwords or Google credentials.
- [ ] Build, inspect, and verify the release artifact: its generated manifest/AAB must show the final package, monotonically increased version code, effective target SDK 36, `admob_live`, the production App ID, and no demo IDs. `package/signed=true` is not proof; inspect the signed AAB and validate a real non-debug install through Play internal testing.
- [ ] On a production-ID test device, reset/reopen consent and exercise UMP handling, rewarded revive, interstitial cadence/dismissal, and the absence of `Remove Ads`. Do not click live ads.

### Task 4: Complete listing, declarations, and internal release

- [ ] Replace all `docs/store-listing.md` placeholders: final title, short/full description, category, support email, policy URL, adaptive icon, feature graphic, and portrait screenshots from the normal game path (not `PIPE_TEST`).
- [ ] Complete Play Console content rating, target-audience/content, ads declaration, Data Safety, support contact, and privacy policy from release evidence.
- [ ] Upload only the signed Live AAB to Internal testing. Inspect and resolve actual pre-launch report, crash, policy, or configuration findings before closed testing.

### Task 5: Recruit 15–20 genuine closed-test volunteers, including Reddit

- [ ] Create the Closed testing track and its opt-in link only after the Live AAB is stable. Add 15–20 volunteers with valid Google/Workspace accounts; the requirement is **at least 12 unique testers continuously opted into the closed test for 14 days before applying for production access**.
- [ ] Before every Reddit/community post, read that community’s self-promotion and beta-test rules. Use Reddit as one recruitment channel alongside permitted Discord/game-dev communities and tester exchanges.
- [ ] Do not buy testers, compensate installs, request ratings/reviews, promise rewards for reviews, create fake accounts, or ask for anything other than honest bug/UX feedback.
- [ ] Post this copy only where permitted, substituting the final opt-in link after a volunteer asks for it:

```text
Title: Android closed testers wanted for Aqueduct, a real-time pipe puzzle

I’m looking for Android players to test Aqueduct, a small real-time pipe-routing puzzle. It is a free Google Play closed test, not a public launch.

What I need: opt in with a Google account, install the game, play a few runs, and stay enrolled for 14 days. I’m after honest bug and usability feedback; I am not asking for ratings or reviews.

The game has rewarded revive ads and occasional interstitials. If you are happy to help, comment or DM and I’ll send the Play opt-in link and a short test brief. Thanks.
```

- [ ] Send volunteers this brief, changing only the link/contact:

```text
Aqueduct closed-test brief

1. Open <OPT_IN_URL> while signed into the Google account you will use for testing.
2. Join the test, install Aqueduct from Google Play, and remain enrolled for 14 consecutive days.
3. Play at least two short sessions. Try pipe placement, flow, difficulty, audio settings, and one rewarded revive if it appears.
4. Send honest feedback to <FEEDBACK_ADDRESS>: device/Android version, steps, expected result, actual result, plus a screenshot or recording if useful.
5. This is product feedback, not a rating or review request. Tell me promptly if you opt out or change Google accounts.
```

- [ ] Track invited, opted-in, installed, feedback, and day-14 status privately (never in Git). Start the clock only when Console shows at least 12 opted in. Retain genuine feedback and the resulting fixes for Google’s production-access questions; engagement matters even though continuous opt-in is the formal threshold.

### Task 6: Apply for production access and publish

- [ ] After Play Console confirms the closed-test requirement, answer the production-access questions truthfully with actual tester feedback, changes, audience, and readiness evidence.
- [ ] Submit the verified Live AAB only after reconfirming package, version code, target SDK, policy link, ads declaration, IARC, Data Safety, support contact, and release notes.
- [ ] Monitor Play Console after approval. Address exact rejection, crash, ANR, policy, or pre-launch evidence with a higher version code; never reuse an uploaded version code.
- [ ] Run final project checks before claiming readiness.

```powershell
& '.\tools\run-gate.ps1'
& '.\tools\android-preflight.ps1' -Target Test
& '.\tools\android-preflight.ps1' -Target Live
```

## External facts to recheck at execution time

- New personal Play accounts need at least 12 closed-test testers opted in continuously for 14 days before production access: [Google Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).
- Google currently requires API 36 for new submissions from 31 August 2026: [target SDK requirement](https://developer.android.com/google/play/requirements/target-sdk).
- Account setup, fees, identity verification, console policy screens, and SDK disclosures can change; verify them in the live Play/AdMob consoles before acting.

## Review record

- Planner self-review covered current Playtest debts: blank production IDs, device-specific UMP testing, consent/privacy/Data Safety, and release-manifest proof.
- Contract review added the strict midnight hold, dirty-worktree protection, exact closed-test wording, and Reddit safeguards.
- Technical review added the reachable fake-IAP removal, separate Live AAB path, effective target-SDK verification, real signing proof, and in-app privacy link.
