# After Google Play Verification

Use this checklist only after Google has approved the Personal Play Console account identity
verification. The app cannot be created before then.

## 1. Finish the account and create the app

1. In Play Console, complete the Android-device and contact-phone verification tasks.
2. Create the app as a game with the permanent package name `com.tokko.aqueduct`.
3. Enrol in Play App Signing and create an upload key. Keep the keystore and its passwords outside
   the repository.
4. Set the public developer contact to `andreas.mikael.gustafsson@gmail.com` and use the approved
   publisher details: Andreas Gustafsson, Flyttblocksvägen 11, Stockholm, Sweden.

## 2. Complete advertising and privacy setup

1. Create the AdMob Android app for `com.tokko.aqueduct`.
2. Create exactly two production units: one Rewarded unit for revive and one Interstitial unit for
   between-run ads.
3. Configure AdMob consent messaging for the EEA, UK, and Switzerland; add each development device
   as an AdMob test device before it receives a production-ID build.
4. Publish the Aqueduct privacy policy and record its public HTTPS URL in Play Console, the store
   listing, and the app. The site deployment started on 2026-07-26; use its final URL once the
   hosting provider reports it.
5. Host an `app-ads.txt` file at the root of the same public developer website after AdMob provides
   the required publisher line.

## 3. Create and test the Play artifact

1. Add a separate signed Android Live AAB export path. Keep the existing `Android` and `Android
   Test` presets unchanged.
2. Configure the real AdMob App ID and both unit IDs in `scripts/monetization_config.gd`; never put
   keystore passwords, Google credentials, or service keys in the repository.
3. Run the Android Live preflight, export the signed AAB, and upload it to Internal testing.
4. Install the Play-delivered build on a physical device and smoke-test normal gameplay, consent,
   rewarded revive, interstitial dismissal, and the privacy-policy link.

## 4. Prepare the listing and declarations

1. Upload a final adaptive app icon, feature graphic, and portrait gameplay screenshots from the
   normal game path.
2. Complete Store listing, Content rating, Target audience, Ads declaration, Data safety, privacy
   policy, and support-contact fields using the actual AdMob and UMP data practices.
3. Verify that the published title remains `Aqueduct` and that any required trademark review is
   complete before the first production upload.

## 5. Earn production access and launch

1. Run the required closed test with at least 12 opted-in testers for 14 continuous days.
2. Apply for production access, answer the testing and readiness questions accurately, and resolve
   any Play review feedback.
3. Release gradually to production after the review is approved and monitor crashes, reviews, and
   AdMob policy notices.
