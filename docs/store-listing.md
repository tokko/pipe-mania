# Store listing scaffold — Aqueduct (working title)

> Scaffold only (epic E7a). The name is the trademark-safe placeholder `Config.GAME_NAME`
> ("Aqueduct") — **run a trademark search and finalize the name before any store submission**
> ("Pipe Mania" / "Pipe Dream" are trademarks). Fill the TODOs before publishing.

- **Title:** Aqueduct
- **Package:** com.tokko.aqueduct
- **Category:** Puzzle
- **Short description (≤80 chars):** Route the pipes, run the water — build the longest leak-free line.
- **Full description:**
  A real-time pipe puzzle. In the calm build phase you place forced pipe pieces to route water from
  the inlet to the outlet — go long and winding, because your score is the length of the shortest
  route the water actually takes. Then tap GO and the water verifies your work: reach the outlet to
  clear and advance to a harder board; spring a leak or touch a bomb and the run ends. Endless
  score-chase, one mistake ends it.
- **Content rating:** TODO (IARC questionnaire — expected Everyone)
- **Screenshots:** TODO (phone portrait: build phase w/ route readout; flow w/ scored-route highlight; bomb proximity)
- **Feature graphic / icon:** TODO (authored art)
- **Privacy policy URL:** TODO (required for release)
- **Monetization:** Rewarded revive plus between-run interstitials. Production IDs remain account-gated.
  Billing, Remove Ads, and cosmetics are deferred and not offered.

## Build and test

1. `& '.\tools\android-preflight.ps1' -Target Test`
2. `& '.\tools\export-ads-build.ps1' -Target Test`
3. Install `C:\Temp\aqueduct-test.apk` on a physical device.
4. Run a labelled Test Ad smoke: verify rewarded revive grants a continue, and dismissing a between-run
   interstitial resumes the run.

Production export remains blocked until the account-gated IDs, privacy URLs, and release signing inputs are supplied.
