# Ads setup and production go-live

The implemented monetization scope is **rewarded revive** plus **between-run interstitials**. Desktop,
headless, and `PIPE_TEST` use deterministic STUB services. Android Test uses the installed Poing Studios
AdMob plugin v4.3.1 and Google test ads. Production IDs are blank and remain account-gated; LIVE stays STUB
until the required IDs are complete and non-demo.

## Human/account steps first

Complete these steps in the relevant Google accounts, then provide Codex only the resulting IDs and URLs.
Do not share credentials, keystore passwords, payment data, or service-account keys.

1. Open [AdMob](https://admob.google.com/) and create or select the Android app with package
   `org.aqueduct.game`.
2. Create one **Rewarded** unit and one **Interstitial** unit. Copy the App ID and both unit IDs.
   Google’s [ID-copy help](https://support.google.com/admob/answer/7356431) explains where to find them.
   Put the complete canonical values in `scripts/monetization_config.gd` as `ADMOB_APP_ID`,
   `AD_UNIT_REWARDED`, and `AD_UNIT_INTERSTITIAL`. Do not edit anything under `addons/admob/`; the project
   override injects the selected App ID into the Android manifest from the shared config.
3. Configure EEA, UK, and Switzerland privacy messaging in AdMob/UMP.
4. Publish a privacy policy and `app-ads.txt`, and provide their URLs.
5. Register every production-ID connected-device at [AdMob test devices](https://apps.admob.com/v2/settings/test-devices).
   Each device needs its own Google-reported UMP debug hash.
6. Complete the app and signing setup in [Google Play Console](https://play.google.com/console/), then provide
   the production signing/export inputs needed for a release build.

## Already automated

- `scripts/services.gd` selects AdMob only when the Android plugin singleton is available; otherwise it stays
  STUB. LIVE fails closed to STUB unless the App ID, rewarded ID, and interstitial ID are all complete and
  non-demo.
- Android Test packages Google Mobile Ads 24.9.0 and UMP 3.2.0 through the Gradle export.
- The export wrapper scopes the Test selector to the Godot export process. Without that selector, the project
  override disables Poing's native libraries, dependencies, and manifest metadata.
- Android Test uses these Google demo IDs:
  - App: `ca-app-pub-3940256099942544~3347511713`
  - Rewarded: `ca-app-pub-3940256099942544/5224354917`
  - Interstitial: `ca-app-pub-3940256099942544/1033173712`
- Samsung `SM-S921B` (`RFCYA02N5LZ`) is registered in TEST with UMP hash
  `71DA107F6DC7F38FD723AD65ACE5D574` and TEST-only `NOT_EEA` geography. Another device needs its own hash.
- Real rewarded revive and between-run interstitial Test Ads were visibly proven on that device; reward and
  dismiss callbacks resume gameplay.

## Verification and release boundary

Run from the repository root:

```powershell
& '.\tools\provision-ads-build.ps1'
& '.\tools\android-preflight.ps1' -Target Test
& '.\tools\export-ads-build.ps1' -Target Test
```

The verified artifact is `C:\Temp\aqueduct-test.apk`. Test the labelled Test Ads on a physical device.
On a clean checkout, provisioning uses the installed official Godot 4.6.2 source-template archive and
verifies its pinned SHA-256; no editor build-template install is needed. The generated `android/build/`
remains ignored, while the committed Poing v4.3.1 Android package is checksum-verified by Test preflight.
The legacy Android preset remains unchanged/prebuilt; Android Test intentionally uses Gradle.

The live build remains blocked until production App ID/unit IDs, privacy-policy and `app-ads.txt` URLs, and
release signing/account inputs are supplied. No production export preset exists yet.

Billing, Remove Ads, cosmetics, and online leaderboards are deferred to separate future plans and are not
offered in this ads scope.

For Google’s test-ad rules, see the [Android test-ad warning](https://developers.google.com/admob/android/test-ads).
