# 43 · Accounts and the server-side fact log (HER-17)

Owner decisions 2026-10-19: Supabase for the backend; sign-in and restore ship before external testers; accounts must be recoverable, editable (grant and take) and fixable. The principle from CLAUDE.md rules 1–4 makes all three cheap: **an account is its fact log.** Progression is derived from immutable facts under a versioned ruleset, so recovery is a replay and an edit is a new fact.

Project: Heroes Journey, `fuwscpmwyaksklwvrohm`, us-west-2, Postgres 17. Migrations live in `supabase/migrations/` and are applied through the Supabase connector (or the SQL editor).

## Tables
| Table | Rows | Who writes |
|---|---|---|
| `profiles` | one per auth user: `profile_id` (the app's local UserID), `state` (the archive as a snapshot for fast restore), `state_version`, `rebuild_required` | the app; admins flip `rebuild_required` |
| `activity_events` | every `ActivityEvent` the app creates, `payload` verbatim plus indexed columns; `inserted_by` client or admin, `reason` | the app (client rows), admins (admin facts) |
| `receipts` | what the authority credited for a fact | the app today; the server once the authority moves |
| `corrections` | a source deletion, duplicate, wrong duration or type, as a fact | the app, admins |

All three fact tables are append-only: a trigger rejects every UPDATE and DELETE for every role, the dashboard included. Row-level security limits each authenticated user to their own rows; client inserts must carry `inserted_by = 'client'`. The service role bypasses RLS for admin work and still cannot change a fact.

## Increment 1 (built 2026-10-19)
- Identity: an anonymous Supabase user on first launch, kept in the keychain (it usually survives a reinstall). `AccountSync` in `App/Sources/Backend/`.
- Binding: `profiles` upsert of the auth user id with the local UserID.
- Upload: after every drain, facts the ledger has processed (and Health history facts) plus their receipts are appended; duplicates are ignored server-side; `uploadedEventIDs` in the archive remembers what went up. Then the archive is uploaded as the profile snapshot.
- Restore: on launch, a fresh install (no recipe, no facts) with a session whose profile has a snapshot adopts it wholesale, rebuilds the authority from the restored ledger and facts, and Home opens where the player left off.
- Offline: every step fails silently and the next drain retries. Nothing in the app waits on the server.

## Increment 2: Sign in with Apple (built 2026-10-19)
Native Sign in with Apple (`AppleSignInButton`, AuthenticationServices) with a nonce: raw to Supabase, SHA-256 to Apple. Two places: Room → Settings → Account (guests), and the onboarding name step ("Already have a character?") for a returning player on a new phone.

Two outcomes, decided by Supabase:
- **Linked.** The id-token grant is sent with the guest session attached; with manual linking on, GoTrue links the Apple identity to the guest user. Same user id, every row stays. Nothing moves.
- **Switched.** The Apple ID already had an account, or linking is off: the device signs into that account. If the server has a character and this device is fresh, the server's character is adopted (the reinstall case). Otherwise this device's character is kept and every fact is re-appended under the new user: facts are keyed `(user_id, id)` since this increment, so the guest's rows never collide.

Supabase settings this needs: Authentication → Providers → Apple enabled with the app's bundle id (`dev.heroesjourney.prototype`) in Client IDs (no secret needed for the native id-token flow); Authentication → Settings → "Allow manual linking" on; Anonymous sign-ins on. Apple Developer: Sign in with Apple capability on the App ID (the entitlement is in project.yml).

Guest users left behind by a switch keep their rows; they can be deleted by the anonymous-user cleanup query in Supabase's docs once they are older than 30 days.

## Increment 3a: recovery safety, deletion, sync visibility (HER-14, built 2026-10-21)
HER-14's acceptance is a TestFlight cohort that can reinstall without losing progress, with QA evidence and the privacy implications written down. Increments 1 and 2 give the mechanism; this increment makes it safe.

**No silent overwrite.** A sign-in that switches to an Apple ID with its own character used to let the phone win and the next snapshot upload replace the account's character. Now `signInWithApple` returns `.conflict` when both sides have progress (anything beyond the bond fact), and the dialog asks which character this phone plays:
- *Use the account's*: this phone's confirmed facts are appended to the log under the account first, then the account's snapshot is adopted. The phone's facts stop driving the ledger; they are not lost.
- *Keep this phone's* (also Cancel): the phone's facts are re-appended and its snapshot replaces the account's. The server keeps what it displaced.
When only one side has progress, that side wins without a question, as before. `profiles.profile_id` stays the character the account was first bound to; `state.userID` is the character it plays now.

**Server guards** (migration `20261021110000_recovery_safety_and_deletion.sql`): a `before update of state` trigger on `profiles` copies the old snapshot into `previous_state` (with its version and time) when a different character takes the row, and raises `serialization_failure` when the same character uploads a lower `state_version` than the server holds. So a stale second device on the same account cannot roll it back; its facts still land, its snapshot is refused and the Account row says so. One device per account is the TestFlight assumption; reconciling two live devices is not built.

**Deletion.** App Store Review 5.1.1(v) requires in-app account deletion for any app that creates accounts, guests included, and external TestFlight builds are reviewed. `delete_my_account()` (security definer, `authenticated` only) sets a transaction-scoped `heroes.erasure` setting that the append-only trigger honours for deletes, erases the caller's corrections, receipts, activity events and profile, then the auth user. The app calls it from Room → Settings → Account, confirmed twice, only when connected; nothing local is touched until the server confirms, then the archive is wiped, a new guest is created and onboarding starts. Apple Health is never written.

**Sync visibility.** The Account row shows "Synced 2 minutes ago", "3 activities waiting to sync" or "Sync failed: …" from `lastSyncAt`, `pendingUploadCount` and `lastSyncError`. Dev controls → Account offers "Simulate fresh install (keep session)" and "Forget session and start over" so both restore paths can be run without reinstalling.

**Migration of existing local characters** needs nothing: the first launch after the update signs in as a guest, binds, uploads every confirmed fact and the snapshot. **Offline** is unchanged: nothing waits on the server; the next drain retries. Privacy inventory, App Privacy answers and the policy draft are in docs/44.

## Increment 3: admin facts and corrections in the engine
`ActivitySource.admin` with `AdminReference(kind: grant | revoke, rewardID?, xp?, attribute?, reason, actor)`, evaluated like story grants; revoke removes a reward grant (rule 4). `ActivityCorrection.Kind` grows to duplicate, wrongDuration, wrongType. The app re-derives its ledger from the fact log when `profiles.rebuild_required` is set.

## How to recover, grant, take and fix (today)
- Recover: the player signs in on the new device; the app adopts `profiles.state`. Until increment 2 this depends on the keychain session surviving.
- Inspect: `select * from activity_events where profile_id = '<UserID>' order by started_at`.
- Grant or take: not until increment 3. Do not edit `state` by hand; it is overwritten by the next upload.
- Fix a bad fact: insert a `corrections` row (increment 3 makes the app honour it).

## Keys
The project URL and publishable key are public by design and live in `AccountSync.swift`. The service role and secret keys never go in the repo or in chat.
