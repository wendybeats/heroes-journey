# 44 · Privacy: what the app collects, where it goes, how it is deleted (HER-14, 2026-10-21)

Written for the TestFlight external cohort. App Store Connect asks for a privacy policy URL before external testing, and the App Privacy questionnaire before any store listing; the answers below are derived from the code as of this increment and must be re-derived when a new data flow lands.

## 1 Data inventory

| Data | Where it is created | Where it is stored | Linked to the person? | Purpose |
|---|---|---|---|---|
| Character: name, body, skin, hair, outfit, backdrop | Onboarding, Room | Phone archive; Supabase `profiles.state` | To the account (anonymous or Apple user id) | App functionality |
| Activity facts: type, minutes, sets, distance, start time, source | Logging, Health import, goals, quests, challenges, story | Phone archive; Supabase `activity_events` (append-only) | To the account | App functionality (progression) |
| Receipts: XP, level before/after, ruleset id | The local authority | Phone archive; Supabase `receipts` | To the account | App functionality |
| Workouts: exercises, sets, weights | Strength logger | Phone archive; inside `profiles.state` | To the account | App functionality |
| Apple Health workouts | Read from HealthKit with permission | Only as derived activity facts (type, minutes, start); raw samples are never stored or uploaded | To the account | App functionality |
| Identifiers | Supabase anonymous user id; Apple user identifier after Sign in with Apple; the app's local character id | Supabase `auth.users`; phone keychain | Yes (they are the account) | App functionality, account recovery |
| Email, name | Not requested: Sign in with Apple asks for no scopes | Not stored | — | — |
| Usage analytics (PostHog): level-ups, quests, fights, screens, app lifecycle | The app, when the Usage analytics toggle is on (default on) | PostHog US cloud, keyed by the character id | To the account (pseudonymous id, no email) | Analytics; product decisions |
| Crash and device data | Apple (TestFlight) | Apple | Per Apple's terms | Diagnostics |

Not collected: contacts, location, photos, purchases, browsing, precise health metrics beyond workout type and duration, advertising identifiers. No third-party advertising SDK. No data is sold.

## 2 Where it is processed
- Supabase project in AWS us-west-2 (United States). Row-level security limits every user to their own rows; the service role is used only by the owner for support.
- PostHog US cloud. Health data is never sent there (the `Analytics` hooks carry no Health fields; the toggle clears the queue when off).
- Apple: Sign in with Apple, HealthKit on the phone, TestFlight.

## 3 App Privacy questionnaire (App Store Connect), as the code stands
- **Health & Fitness → Fitness**: collected, linked to the user, not used for tracking. Purpose: app functionality.
- **Identifiers → User ID**: collected, linked, not for tracking. Purpose: app functionality, analytics.
- **Usage Data → Product Interaction**: collected, linked (pseudonymous id), not for tracking. Purpose: analytics, app functionality.
- **Diagnostics**: crash data via Apple only; if a crash SDK is added later, declare it.
- **Contact info, user content beyond the above, location, purchases, browsing, search history, sensitive info**: not collected.
- **Tracking** (data linked across apps/sites for advertising): none. The app does not ask for ATT permission.

## 4 Deletion and retention
- In-app: Room → Settings → Account → "Delete account and data", confirmed twice, requires a connection. `delete_my_account()` erases the user's corrections, receipts, activity events, profile and auth user; the phone archive is wiped; a new guest starts. Apple Health is untouched. PostHog retains the pseudonymous events under the old character id; deleting a person there is a support action (PostHog → Persons → delete) until an API call is wired.
- Guest accounts abandoned by a switch to an existing Apple account keep their rows; the owner may purge anonymous users older than 30 days with Supabase's documented cleanup query.
- Backups: Supabase's daily backups hold deleted rows for their retention window; this is standard and should be stated in the policy.

## 5 Privacy policy draft (for the landing page; the owner publishes)
Heroes Journey ("the app") is made by Wendell Barton. This policy covers the TestFlight preview.

**What we collect.** The character you create (name, look, outfit), the activities you log or import (type, duration, time, sets or distance), the rewards the app grants, your workouts in the strength logger, and anonymous usage events (which screens and features you use). If you connect Apple Health, we read your workouts and keep only their type, duration and start time. If you use Sign in with Apple, we receive an Apple account identifier and nothing else: no name, no email.

**Why.** To run the game: your progress is computed from your activities. To keep your character if you change phones. To understand which parts of the preview work, through anonymous usage events you can turn off in Settings.

**Where.** Your account data is stored with Supabase in the United States. Usage events are stored with PostHog in the United States. Health data stays on your phone except as the derived activity records above.

**Who sees it.** Only you, through the app, and the developer for support. We do not sell data, show ads, or share data with advertisers.

**Your choices.** Turn usage analytics off in Settings. Disconnect Apple Health in iOS Settings → Health. Delete your account and all its data in Settings → Account; this is immediate and permanent (database backups expire within their normal retention period).

**Children.** The preview is for adults; we do not knowingly collect data from children under 13.

**Contact.** hello@wendellbarton.com.

**Changes.** We will update this page when the app changes what it collects.

## 6 Before the store listing
- Publish the policy at a stable URL (landing page, HER-15) and enter it in App Store Connect → TestFlight → Test Information and → App Privacy.
- Re-check this inventory when: a crash SDK, push notifications (HER-24), payments (HER-11) or email collection lands.
