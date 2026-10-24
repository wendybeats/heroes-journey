# 46 · TestFlight from CI (owner, 2026-10-24)

Owner decision: get TestFlight rolling now, without a Mac at hand. The repo's CI archives the app on a GitHub macOS runner, signs it automatically with an App Store Connect API key, and uploads it to App Store Connect. No certificates or profiles live in the repo; the key lives in GitHub secrets. Workflow: `.github/workflows/testflight.yml` (manual trigger, "Run workflow" on GitHub → Actions → testflight).

## One-time owner setup (all in a browser)
1. **App record.** App Store Connect → Apps → "+" → New App: iOS, name "Heroes Journey", bundle id `dev.heroesjourney.prototype` (already registered as an App ID), SKU anything (`heroes-journey-ios`). Primary language, then Create.
2. **API key.** App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → "+": name "GitHub TestFlight", access **Admin** (App Manager cannot create signing certificates). Download the `.p8` once (it cannot be downloaded again); note the **Key ID** and the **Issuer ID** shown on that page.
3. **Team ID.** developer.apple.com → Account → Membership details → Team ID (ten characters).
4. **GitHub secrets.** Repository → Settings → Secrets and variables → Actions → New repository secret, four of them:
   - `APP_STORE_CONNECT_API_KEY_P8`: the whole text of the `.p8` file, including the BEGIN and END lines.
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APPLE_TEAM_ID`
5. **Capabilities on the App ID** (developer.apple.com → Identifiers → the App ID): HealthKit and Sign in with Apple ticked. Automatic signing from CI can usually add them, but ticking them once removes the most common first-run failure.
6. After the first upload: App Store Connect → the app → TestFlight → Internal Testing → "+" group, add yourself. Internal builds need no review; the TestFlight app on the phone shows the build about 10–20 minutes after the upload finishes.

## Running it
GitHub → Actions → testflight → Run workflow on `claude/tender-hamilton-d57cv9` (or any branch). Inputs: `dev_controls` (default on: the owner's QA builds carry the Dev controls, compiled through the `DEVCONTROLS` condition; turn it off for cohort builds), `marketing_version` (default 0.1.0). The build number is the workflow run number, so every upload is unique. The job prints the uploaded build number and the commit. Expect 12–20 minutes on the runner.

## What is in the repo for it
- `App/ExportOptions.plist`: `app-store-connect` method, `destination upload`, automatic signing; the team id is filled in by the workflow.
- `App/Resources/Assets.xcassets/AppIcon.appiconset`: a placeholder 1024 icon (the base character on navy, composed from the kit). App Store Connect refuses builds without an icon. Replace with the owner's icon art when it exists; the catalog entry stays.
- project.yml: `MARKETING_VERSION` 0.1.0, `CURRENT_PROJECT_VERSION` 1 (overridden per run), `ITSAppUsesNonExemptEncryption: false` (HTTPS only, so no export-compliance prompt on each build), the asset catalog as a resource.
- `#if DEBUG || DEVCONTROLS` on the dev controls, so a Release build can carry them when asked.

## Release builds and QA
A TestFlight build is a Release build. With `dev_controls` on it has the wrench and everything in Dev controls, so the docs/30 lists run on it unchanged. The dev day offset and the account simulations work the same. Cohort builds (HER-7) go out with `dev_controls` off.

## First-run failures and what they mean
- "No profiles for 'dev.heroesjourney.prototype' were found" or a capability error: step 5 above, or the API key is not Admin.
- "Missing required icon file": the asset catalog did not make it into the archive; check project.yml generated the catalog resource.
- "ITMS-90xxx" after upload (email from Apple): paste it on HER-7; most are Info.plist keys.
- A build that uploads but never appears in TestFlight: App Store Connect is still processing, or the build number repeated (it cannot with the run number).

## Later
- Automatic upload on a tag (`tf-*`) once the manual run is proven.
- Xcode Cloud is the alternative (Apple-hosted, free tier). It needs the generated `.xcodeproj` committed, which this repo avoids; revisit if the GitHub path turns out brittle.
