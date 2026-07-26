# AdMob Android Test APK Playtest

## Scope And Playtest Evidence

- Device: Samsung SM-S921B (`RFCYA02N5LZ`), Android arm64, 1080 x 2340.
- Artifact: `C:\Temp\aqueduct-test.apk`, 89,236,705 bytes, SHA-256 `BAB8A77FF694DB2992796D336FFF1F1B086BBA83E6B42EB393CB4F3133CDFB38`.
- Shipped entry point: `org.aqueduct.game/com.godot.game.GodotAppLauncher`, launched without `PIPE_TEST`.
- Fresh install and cleared app data reached menu, gameplay, flow failure, and RUN OVER through touch-equivalent ADB input.
- Revive opened a native Google rewarded surface visibly labelled `Test Ad`. The surface displayed `Reward granted`; logcat recorded `Ad showed fullscreen content`, `Ad recorded an impression`, and `User earned the reward`.
- Closing the rewarded surface returned to the same Hard run with `Flow in 30s`, proving the reward callback revived gameplay without starting a second logical run.
- Failing that revived run completed logical run one. Starting and failing a second Hard run did not show an interstitial early.
- Selecting Hard for the next run opened a native Google interstitial visibly labelled `Test Ad` and stating `This is an interstitial test ad.` Logcat recorded interstitial load, fullscreen display, impression, and dismissal.
- Closing the interstitial mounted the selected Hard board with `Flow in 30s`, proving gameplay waited for the terminal ad callback and preserved the chosen difficulty.
- No Godot script error, Android fatal exception, or app crash occurred in the exercised path.

## Solutions Applied

- Added a strict Android TEST mode using only Google's demo App ID and rewarded/interstitial unit IDs.
- Kept desktop, headless, `PIPE_TEST`, incomplete LIVE configuration, and missing-plugin environments on deterministic stubs.
- Added UMP-before-Mobile-Ads initialization and fail-closed error/denial handling.
- Added TEST-only UMP `NOT_EEA` debug geography plus the connected Samsung's UMP test-device hash, avoiding an automated personal-data consent choice.
- Added guarded rewarded and interstitial UI flows so one request produces one terminal result, conflicting actions are disabled, and duplicate taps cannot create duplicate ads.
- Counted unique completed logical runs for interstitial cadence: no ad at session start or after run one, then every second completed run; abandoning to Menu does not count and revive does not double-count.
- Added a dedicated Android Test export, target-aware preflight, deterministic provisioner, and deterministic export script.

## Deliberate Shortcuts And Debt

- The UMP test-device registration contains only hash `71DA107F6DC7F38FD723AD65ACE5D574`; another physical test device must add its own Google-reported hash before the TEST geography override applies.
- Production AdMob IDs remain intentionally blank. LIVE mode therefore fails closed to STUB until the publisher account and app/ad units exist.
- Billing and online leaderboards remain deterministic stubs and are outside this ad integration.
- Test screenshots are local device-run evidence rather than committed binary artifacts.

## Outstanding Fixes

- Replace the blank production AdMob App ID and ad-unit IDs only after the Google AdMob app is created and approved.
- Register any additional physical Android test devices before automated consent-free device testing.
- Complete the production privacy/consent configuration and store data-safety declarations before release.

## Stabilization Follow-Up

- Keep the focused TEST-vs-LIVE consent-parameter tests and the full headless gate in every ad change.
- Run the Android Test preflight/export and a physical-device rewarded/interstitial smoke test before changing plugin or Google Mobile Ads versions.
- Before a release build, verify the packaged manifest, dependencies, custom feature, production IDs, privacy policy URL, and Play Console declarations independently of this test APK.
