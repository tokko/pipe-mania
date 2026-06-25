# Monetization & Online Services — Setup (account-gated)

This game ships with a **working monetization UX** (Remove-Ads persists, Revive grants a continue,
a between-runs interstitial seam) and a **local top-10 leaderboard** — all behind the `Services`
abstraction. The ad/IAP calls run against **dev stubs** that succeed instantly, so desktop and
headless development need no accounts.

Going **live** (real AdMob ads, real Play Billing purchases) needs your accounts + the v2 Android
plugins, which can't be set up or tested without your credentials. This doc is the checklist.

## What's already scaffolded (no action needed)

- **Runtime dispatch** — `scripts/services.gd` `_ready()` upgrades each service to a real adapter
  **iff** its Android plugin singleton is present (`Engine.has_singleton(...)`), else keeps the dev
  stub. Headless/desktop → stub (so the gate stays green); a real device with the plugins → live.
- **Config placeholders** — `scripts/monetization_config.gd` holds the ad-unit / product / singleton
  constants (all empty/default today). The `*Real` adapters read these.
- **Callback-driven grants** — both the stub and the real adapter emit `reward_earned` /
  `purchase_succeeded`; the grant (revive / set ads-removed) runs in the signal handler, so wiring
  the real SDK requires **no caller changes**.

> **Note on "secrets":** AdMob app/ad-unit IDs and Play Billing product IDs are **not secret** —
> they are embedded in every published APK. `monetization_config.gd` is committed with empty
> placeholders; filling in your real IDs and committing them is fine. (Keystores and service-account
> JSON **are** secret — never commit those.)

## Accounts / credentials you must provide

| Need | Where | Used for |
|------|-------|----------|
| Google Play Console account (one-time $25) | play.google.com/console | publishing, IAP products, signing |
| AdMob account | admob.google.com | App ID + ad-unit IDs |
| A **Rewarded** ad unit ID | AdMob → your app → Ad units | the Revive ad |
| An **Interstitial** ad unit ID | AdMob → your app → Ad units | the between-runs ad |
| A managed in-app product `remove_ads` | Play Console → Monetize → In-app products | the Remove-Ads purchase |
| Upload/signing keystore | you generate (`keytool`) | signed AAB (IAP + ads only work on a Play-distributed build) |

## Steps to go live

1. **Fill `scripts/monetization_config.gd`:** `ADMOB_APP_ID`, `AD_UNIT_REWARDED`,
   `AD_UNIT_INTERSTITIAL`. (`BILLING_PRODUCT_REMOVE_ADS` already defaults to `remove_ads` — match it
   to the Play Console product id.)
2. **Godot editor → Project → Install Android Build Template** (the custom Gradle build the v2
   plugins require).
3. **Install the plugins via AssetLib** (Project → AssetLib): the Poing Studios **AdMob** plugin
   (4.6-compatible) and the first-party **GodotGooglePlayBilling**. Enable both in Project →
   Plugins, and tick them in the Android **Export → Plugins** tab.
4. **AdMob App ID** is injected by the AdMob plugin's export options (it writes
   `GADApplicationIdentifier` into the generated manifest) — do **not** hand-edit AndroidManifest.
5. **Flip the export to gradle:** set `export_presets.cfg` `gradle_build/use_gradle_build=true`.
   ⚠️ This switches off the verified **prebuilt-template** APK recipe and now needs the build
   template (step 2) + a configured NDK. Only do this once the plugins are installed — it is
   deliberately **left `false`** until then so the current recipe keeps working.
6. **Confirm the AdMob singleton/API name** the installed plugin exposes. If it differs from
   `"AdMob"`, update `MonetizationConfig.ADMOB_SINGLETON` and the `AdServiceReal` body.
7. **Wire the `*Real` adapters** in `scripts/services.gd` (search `TODO(Phase 5)`):
   - `AdServiceReal`: load+show the rewarded/interstitial ad; emit `reward_earned("revive")` **only**
     from the SDK's reward callback (never right after the show call).
   - `IapServiceReal`: start the billing flow; emit `purchase_succeeded("remove_ads")` from the
     acknowledged-purchase callback.
8. **Build a signed AAB**, upload to a closed testing track, and test on a device signed in with a
   license-tester account — **rewarded ads and IAP only work on a Play-distributed signed build**,
   not a sideloaded debug APK.

## Leaderboard (later, optional)

The leaderboard is **local** today (device top-10, `SaveStore`). The `Services.leaderboard`
interface (`submit_score`, `get_top`) is stable, so an online backend (Google Play Games Services or
a custom REST service) drops in by adding a `LeaderboardServiceReal` and dispatching it the same way.
That interface is **synchronous** today; an online backend will need a signal-based async wrapper —
add that when you wire it, don't pre-build it.

> **Anti-cheat:** local scores live in plaintext `user://` and are trivially editable. When an online
> backend is added, validate submitted scores server-side rather than trusting the client value.
