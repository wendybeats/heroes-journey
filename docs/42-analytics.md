# 42 · Product analytics (HER-6, owner decision 2026-10-19: PostHog)

PostHog, US cloud, project "Default project" in the Heroes Journey organisation. The iOS SDK (`posthog-ios`, SwiftPM) sits behind `AnalyticsClient` in `App/Sources/Analytics/`; the app target is the only place that knows PostHog exists. HeroDomain and HeroContent stay Foundation-only.

## What is sent
Our named events plus the SDK's lifecycle events (`Application Opened`, `Application Backgrounded`, `Application Installed`, `Application Updated`), which carry D1/D7/D14/D21/D30 retention. Nothing else: no autocapture, no screen views, no element interactions, no session replay, no feature-flag calls.

| Event | When | Properties |
|---|---|---|
| onboarding completed | Seal the bond | primary_family, secondary_interest, health_connected |
| health connected | Apple Health authorisation returned without error | |
| activity logged | a credited activity receipt (manual, structured workout, Health import, steps) | source, family, first (the first activity ever credited) |
| goal completed | a goal receipt | slot (primary / secondary / small_win), attribute |
| quest departed | the character leaves | quest |
| quest claimed | the cache is claimed | quest, tier (common / uncommon / rare / none), page |
| challenge offered | the day's offer is rolled | challenge, character |
| challenge resolved | the clash resolves | challenge, won, probability |
| level reached | a receipt crosses a level | level |
| ascension reached | a level crosses an Ascension tier | tier |
| boss attempted | a fight ends | boss, result (won / lost / stalled), turns, stamina_share |
| chapter completed | the closing milestone completes | chapter |

Person: identified at launch with the local user id, and again at onboarding with primary_family and secondary_interest as person properties. When accounts land (HER-17) the account id becomes the distinct id and the local id is aliased to it, so cohorts survive.

## What is never sent
Durations, workout types, distances, sets, step counts, Health sample ids, names. Health facts appear only as `activity logged` with source `health_import` or `steps` and the family they fed.

## Opt-out
Room → Settings → "Usage analytics". Off calls the SDK's opt-out, which clears the queue; the choice is stored in UserDefaults (`analytics.enabled`), outside the archive, default on.

## Key
The PostHog project API key is write-only and public by design (every client app ships it), so it is a constant in `PostHogAnalytics.swift`, not an environment secret. The personal and service keys that read data never go in the repo.

## Verifying
One session on a device: onboarding, one logged activity, one goal, one quest departure. Then in PostHog, Activity → Live events, or through the connector: `read-data-schema` lists the event names, and a trends query on `activity logged` shows the property values. HER-6 is Done when every row in the table above has appeared once with the expected properties.
