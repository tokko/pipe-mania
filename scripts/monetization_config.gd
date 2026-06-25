extends RefCounted
## Monetization config — placeholders until the real IDs are supplied (account-gated; see
## docs/MONETIZATION_SETUP.md). These are NOT secrets: AdMob app/unit IDs and Billing product IDs
## ship in every published APK. The `*Real` Services adapters read the credential consts; the
## singleton-name consts drive the Engine.has_singleton() real-or-stub dispatch in services.gd
## (present on a real device with the v2 plugins -> *Real; absent / headless -> dev stub).

# Android plugin singleton names (the dispatch seam).
const ADMOB_SINGLETON := "AdMob"
const BILLING_SINGLETON := "GodotGooglePlayBilling"

# Credential placeholders (empty until supplied).
const ADMOB_APP_ID := ""
const AD_UNIT_REWARDED := ""
const AD_UNIT_INTERSTITIAL := ""
const BILLING_PRODUCT_REMOVE_ADS := "remove_ads"
