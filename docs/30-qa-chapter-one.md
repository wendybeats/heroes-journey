# 30 — QA list: chapter one build (2026-10-05)

Build: branch `claude/tender-hamilton-d57cv9`, commit in the increment 28 entry of doc 20. `xcodegen generate && open HeroesJourney.xcodeproj`, run on a simulator or device. Reset the app (delete it) between full passes; the archive persists quest runs and story progress.

## A. Story director and chapter one
1. Fresh install → onboarding plays the awakening; after the bond, Home shows no scene replay (milestone 1 recorded).
2. Reach Level 2 (log activity; the dev cap is 40 XP/day plus goals) → the "home" chapter plays once the screen is quiet (no reward modal, no stage). The room button (house) appears in the toolbar after it finishes.
3. Kill the app mid-chapter → relaunch replays the same chapter; it never skips and never plays twice after finishing.
4. Levels 3–4 → Protein Row and rumours chapters, one per level, in order. Level 5 → gym gate chapter; the daily quest becomes Colossus Gym 01 (8 h).
5. Level 10 → no auto chapter; Home shows the story card "Face Colossus". Tapping plays the resolution with the Central Hill tease; the card disappears after; Colossus speaks with his close-up portrait (gym vignette).
6. The quest's end scene plays after a gym quest is claimed, not before.

### Home layout (2026-10-06)
- Scene shows only the character, the backdrop and the away/back card. Under it: a glass strip with XP, the bar and the level badge, then the attributes strip. Level-up: the counter and badge flash still play in the new position.
- Idle character is the original size on Home, room, stage and onboarding; the departure walk is a third smaller.

## B. Scene-one backdrops (status review)
7. Room hub: the room still, character in front, appearance / equipment / where-you-stand / progress / settings sections work. Changing hair or skin updates the character live.
8. Protein Row still behind the Level 3–4 chapters; gym exterior behind the Level 5 chapter; gym interior behind gym chapters.
9. Departure on Protein Row (Levels 3–4) and inside the gym (Level 5+): the panorama scrolls right to left and wraps with a short dark gap, no hard seam. First walk unchanged at Levels 1–2.

## C. Quest, cache and claim
10. Finish all goals → "Begin quest" → notification prompt → departure screen: walk, dotted path, countdown, cache tooltip lists one item per tier for *this* quest.
11. While away: Home scene shows "Away · tap to look"; reopening shows the departure screen.
12. After the return time (foreground or via notification): no reward modal fires. Home shows "Back · open the cache" with a pulsing cache; goals card says "Back. Something came back too." with an "Open the cache" button.
13. Quest screen when back: walk stopped, path complete, cache glows in the rolled tier's colour (silver / blue / pink), "Tap the cache", bottom button reads "Later".
14. Tap the cache → claim modal: item still, name, rarity, one sentence, Claim. Claim → modal closes, Home shows the XP receipt (and level-up if any), then the end scene if the quest has one.
15. Tap "Later" → nothing is lost; the cache still waits; the story does not advance past it.
16. Kill the app before claiming → relaunch shows the same cache and the same item.
17. Fourth return on the first walk (pool owned): the modal shows the item dimmed, "Already yours", "Traded in for +N XP" where N is the row XP plus the trade-in (20 / 30 / 50).
18. Eight resolved runs without a rare → the ninth roll is rare (pity). Hard to reach in a day; verify by reading the tier eyebrow over several days or accept the unit test.

## D. Items on the character
19. Fresh install: the character wears the starter outfit (grey hoodie, dark sweats, worn trainers) on the canonical body from the first onboarding frame. Room → Equipment lists the three starters plus claimed items with their stills.
20. Equip anything at any level: it shows at once; belt and a top together; a cap hides the hair; shoes stay planted while the torso breathes. Unequip the top → the bodysuit shows. Older saves open already dressed.
20a. Wearing any top or the wraps: the male character never raises or flexes an arm; take them off and the flex returns within ~10 s. With a cap or shades on, nothing on the head shears or drifts during the idle.
20b. Level 5 ascension: the body does not change. At the reveal the eyes turn gold and broken arcs turn slowly behind the character; both persist on Home, in the room and on the quest screen. Level 10 adds drifting pixels. Reduce Motion: field static.
21. Reduce Motion on: the cache does not pulse; the character holds the pocketed pose with trainers still visible.

## E. Regressions to spot-check
22. Reward modal for a workout or goal still shows XP, attributes, PRs; "Unlocked: …" names items, not ids.
23. Ascension at Level 5 still runs; the suit (kit v2) renders; trainers are not expected on the suit.
24. History, log sheet, Apple Health connect, weight unit: unchanged.
25. Content version shows 2026.10.05-5; asset registry builds; `Tools/validate_sprites.py` passes on every revision (CI does this).

## F. Dev controls (DEBUG builds, wrench icon top-left on Home)
26. Advance one day → stage screen, new goals, quest ready again once goals are done; "Back to today" restores.
27. Finish the quest now → the cache appears on Home within a second.
28. Remove the daily cap → the Home "Activity XP today" line disappears and a logged session earns full XP; toggle back restores the cap.
29. Reset today's goals → a different set of three.

## Known gaps (not bugs)
- Items do not show on the departure walk (baked strip).
- Only Clean Trainers has a wearable layer, and it is a placeholder.
- Level 10 reward is still TBD; legendary cache unused; Colossus portrait, loot-box open state, and the hood-up idle are pending art.

## QA for build 89b3d0f (2026-10-18): play-through queue, strain, steps, personalisation

Fresh install unless a line says otherwise.

**Onboarding**
1. Hair: pick wolf cut, switch body to female → ponytail, colour kept; switch back → wolf cut.
2. Chips (style, colour) show no inner capsule on iOS 26.
3. Physical and secondary options carry attribute glyphs at the trailing edge in the attribute colours.
4. Two new steps after the motivation question: "What does your human want more of? Pick any." and "And what do they find hard to keep up?", five rows each (Body, Mind, Calm, Make, Order) with a line under each, any number selectable, Next always enabled.
5. Health step: after Connect, the "Apple Health · Connected" card; the sentence is gone.
6. Bond step: the character glows up, "+6 <attribute> · from your <family>" lands, then "+4 <attribute> · from your interest in <interest>", then the closing line; Seal the bond is disabled until then. Reduce Motion shows it all at once.

**Day one with Health**
7. Home opens with the Health welcome card (your line, step count, workouts, XP); the numbers hold at the pre-credit values until Good, then one level-up plays.
8. The home scene and any challenge wait until the first thing you do by hand (log a session, tap a goal), then play.

**Home**
9. Today card: "4,091 steps · +16 xp" style row; the day's raw XP row with "Strained · 50 %" once past 120; "No sessions yet. Steps are counting." when only steps; "Health · synced 2 minutes ago" on the right.
10. Tapping "Read for 10 min" opens the log sheet on Reading; "Change" returns to the list. A manual goal still completes by tap.
11. After any log, Home is at the top when the bar moves.
12. Dev panel: the Ascension tier picker changes the idle on Home; the Strain row shows the bands and the raw XP; "Remove strain" turns it off.
13. A second 60-minute session in a day credits about half; the receipt shows the smaller number without a lecture; past 400 raw XP the receipt says "Enough for one day."

**Story**
14. A cutscene that opens an area shows "New area · Colossus Gym" (or "New scene · …", "Your room is open") over the stage for three seconds.
15. Dialogue portraits are 160 pt in a frame; the bubble sits on the speaker's side under their name; hero always on the left; "Tap to continue" pulses.
16. The first time Face Colossus is offered, Cairon's "That's him, at the bottom of the stairs…" plays before the glowing boss card.
17. The boss card: "Boss · Under City", the portrait, one filled button, a slow gold pulse; a challenge the same day sits below it.

**Ascension (Level 8, or the dev replay)**
18. Slow rise with the glow building, four gold strikes with the room flashing, the eyes light, whiteout, the final flash, then the ascended character held with "Ascension is here" and its name; nothing advances until Continue; then the settle and the scene.

**Quests and pages**
19. A gym quest's cache: the gear card, then "There was something else in it." → Next → the page card with the log line and the hero's remark → Claim. Pages arrive in order.
20. Departure screen: "I'll let you know when I'm back." under the countdown once notifications are allowed.

**Fight**
21. Sprites switch states; fighters near the edges; his bar left, yours right under your name; no advance telegraph; ANALYZE shows "READ · Crush" once; Guard braces and ripples on his hit; Center's beads converge; "BROKEN · one free action" with the Attack button lit; Pressure explained once; MORE darkens the room; PHASE II at half his Stamina; the victory sequence and "Colossus defeated · For the first time in eleven years, he stops."
22. Each verb's first use shows its build line ("ATTACK · Strength advantage…").

**History**
23. One Steps row a day with a Health tag; Health imports carry the Health badge.

## QA for build 2e064f9 (2026-10-18): second device batch

Fresh install for 1–3; the rest on an existing save.

**Onboarding and Health**
1. Cairon's card in the guide rows (onboarding, Health welcome) faces his bubble, to the left.
2. Connect Health on an account with a long history: the welcome card counts only today's workouts; no level jump from history. The timeline still shows older workouts as history.
3. A session done earlier today, before connecting, is credited on connect.

**Story**
4. "Your room is open" / "New area · …" sits under the scene graphic, centred, gold with a thin gold stroke, and holds about 3.5 s. Nothing cut off at the top.
5. Any speaker on the right (Cairon, the lifter) faces the hero on the left.
6. The first Face Colossus offer: Cairon's line plays with "Colossus fight unlocked" under the graphic; then the boss card.

**Goals and quests**
7. Tap "Play or practise music for 15 min" → log sheet on the Make tab, no activity preselected. "Recover for 10 min" → Calm. "Read for 10 min" → Mind. "Draw for 15 min" → Make.
8. First quest departure: a small bell card "I'll let you know when I return." above Enable notifications.

**Ascension (dev replay, tier II)**
9. Ascension II: purple lightning and purple eyes; the rest of the sequence unchanged. Tier I now strikes in its own blue (the strikes were gold before); the white core of each bolt is unchanged.

**Fight**
10. Unchanged on purpose: the Colossus still ends near where you left him (options in doc 37, awaiting a pick).

## QA for the Colossus fourth tuning (2026-10-18, same branch)

**Fight**
1. First MORE: the Pressure pop reads "Your attacks land softer. His land harder."
2. At two or more Pressure, let the Crush land without guarding: KO in red over the hero with "Two plates of Pressure and you stood there. Guard the swing.", then the loss card. Guarding the same Crush is a normal Deflect.
3. At one Pressure an unguarded Crush is a hit, not a KO.
4. His TEST and Crush numbers climb with the stacks (about +15 % per stack); Center brings them back down.
5. Expectation for your build: a tactical fight ends with roughly half your bar, down from 70 %.

## QA for analytics (HER-6, 2026-10-19)

1. Room → Settings shows "Usage analytics", on by default, with the caption "Level-ups, quests, fights. Never Health data."
2. Fresh install, complete onboarding, log one activity, complete one goal, depart on a quest. In PostHog Live events: Application Installed, Application Opened, onboarding completed, activity logged (first = true), goal completed, quest departed, in that order.
3. Turn the toggle off, log another activity: nothing new arrives. Turn it on, log again: it arrives.
4. No event carries a duration, a workout type, a distance or a step count.

## QA for accounts, increment 1 (HER-17, 2026-10-19)

1. Fresh install, complete onboarding, log one activity. In Supabase: one `profiles` row with your character's id, rows in `activity_events` (the bond fact and the activity) and `receipts`, and `profiles.state` filled.
2. Delete the app, reinstall, open it: if the keychain kept the session, Home opens with your character, level and history within a second or two, without onboarding. If it shows onboarding instead, the session did not survive; note it, Apple sign-in (increment 2) is the fix.
3. Airplane mode, log an activity, come back online, log another: both facts arrive on the next sync.
4. Nothing in the app waits on the server: Home and logging behave the same with the network off.

## QA for Sign in with Apple (HER-17 increment 2, 2026-10-19)

1. Room → Settings → Account reads "Guest" with the Apple button and "Sign in to keep your character if you change phones." Tap, authorise: the row reads "Signed in with Apple" and the button is gone. In Supabase → Authentication → Users the user now has an Apple identity and is no longer anonymous (linked case), or a new user appears (switched case; note which).
2. Delete the app, reinstall, on the name step tap "Already have a character?" → Apple: Home opens with the character, level, history and quests, no onboarding.
3. Cancel the Apple sheet: no error text. Deny or fail: a short error line under the button, nothing else changes.
4. A second device with its own guest character, sign in with the same Apple ID: the account's character replaces the fresh guest only when the device had no activity; otherwise the device's character stays and its facts appear under the Apple user in Supabase.

## QA for HER-20 (Health imports under a dev day offset, 2026-10-19)

1. With Day offset 10 in Dev controls, record a workout in Health (or let WHOOP write one), then open the app: the receipt reads the full session (about 15 + 2 XP per minute, strained only by today's other activity), "Train for 30 min" completes if it ran 30 minutes or more, and the Today card counts it as a session.
2. Dev controls → Last receipt shows "Started" without "(not the app's today)".
3. Back to today (offset 0): a Health workout from earlier today behaves the same as before.

## QA for HER-14 (recovery safety, deletion, sync visibility, 2026-10-21)

1. **Reinstall with session.** Dev controls → Account → "Simulate fresh install (keep session)": the app returns to onboarding for a moment, then Home opens with your character, level, history, workouts and chapter progress. Nothing to type. (Same as deleting and reinstalling the app when the keychain keeps the session.)
2. **Reinstall without session.** Dev controls → Account → "Forget session and start over": onboarding appears. On the name step tap "Already have a character?" → Apple: Home opens with your character, no onboarding. The Account row reads "Signed in with Apple".
3. **Conflict.** Forget session, complete onboarding as a new character, log one activity, then Room → Settings → Account → Sign in with Apple: a dialog names the account's character (level, activities, last active) and this phone's, with "Use … from the account", "Keep … on this phone" and Cancel. Pick "Use": the account's character comes back and, in Supabase, the new character's activity row exists under the Apple user. Repeat and pick "Keep": the phone's character stays; in Supabase `profiles.previous_state` holds the displaced snapshot and `previous_state_replaced_at` is set.
4. **Sync line.** After logging an activity online the Account row reads "Synced a few seconds ago". In airplane mode log one: "1 activity waiting to sync". Back online, after the next drain: "Synced …". If the server refuses something, "Sync failed: …" appears and the app keeps working.
5. **Deletion.** Settings → Account → "Delete account and data" → confirm → "Delete": the app returns to onboarding as a new guest. In Supabase → Authentication → Users the user is gone and `activity_events` has no rows for it. In airplane mode the button is disabled (Offline) or the attempt reports that nothing was deleted.
6. **Existing character, first launch after the update.** On a phone that already had a character: Home opens unchanged; within a minute the Account row reads "Synced …" and Supabase holds its facts and snapshot. Nothing was asked, nothing moved.

## Owner device run 2026-10-23, build 17620be: first finding
- Account row read "guest · 710 pending · there is no unique or exclusion constraint matching the ON CONFLICT specification". The upload named the pre-increment-2 keys (`id`, `submission_id`); the server keys facts `(user_id, id)` and receipts `(user_id, submission_id)` since migration 20261019101500. Fixed in the next commit; the 710 facts were waiting on the phone and go up on the first sync after the fix. The sync line did its job: the failure was visible without the dashboard.

## QA for HER-27, HER-28 and the week grid (2026-10-23)

**Health welcome only before onboarding (HER-27)**
1. Fresh character; after onboarding, do a Health workout (or let WHOOP write one) and open the app: a normal receipt ("Logged", type, minutes, XP), no "your human is already active" card, and the Level 2 room intro plays on the next Home visit once Level 2 is reached.
2. Fresh install with a workout already in Health from earlier today, then onboard: the welcome card with that workout counted; the story holds until your first manual action (a logged session, a finished workout, a tapped goal).
3. Day two with the welcome card never dismissed: Health credit arrives as receipts, nothing is held.

**Steps moments (HER-28)**
4. Walk past 5,000 steps with the app closed, then open it: the receipt reads "Steps counted · 5,000 steps · +20 XP today". Same at 10,000 (+40). Between moments a sync stays quiet; the Today row keeps counting.
5. Past 20,000: the Today row keeps earning but slower on a day with sessions (strain), and still at the full rate on a quiet day. Nothing stops at 20k.
6. A steps moment never fires on the onboarding day while the welcome card is up.

**Week grid**
7. A boxing (combat) session of ten minutes or more lights both the Strength hand and the Endurance shoeprints for that day. A run lights only the shoeprints; a strength session lights only the hand.

## Owner device run 2026-10-24, build 8455371: findings and fixes (B–E)

Passed: the fight tuning (B), Health under the dev clock (C: a 60-minute strength session at offset 3 credited in full, landed on the app's day, History shows the offset days ahead of the real calendar, which is the dev clock working), offline logging and the re-sync (E), Sign in with Apple (switched path, 756 facts re-appended under the Apple user).

Fixed in the next build:
1. Fight: the tutorial lines and action hints were fading text on the stage. They now show as a small glass card under Colossus's bar for a few seconds; single words and numbers stay as pops.
2. Receipt modal names the session: "Weightlifting · 60 min · Apple Health" under the XP.
3. Dev controls → Last receipt read "none" after the modal was dismissed; it now falls back to the latest confirmed session receipt.
4. The bionic-hand lifter's dialogue card was mirrored on the right; it is authored facing left, so it now draws unmirrored (`card_portrait_asset_set_id`).
5. Offline: the Account row showed the raw NSURLError text; it now reads "Offline · 1 activity waiting to sync".
6. History showed `quest.quest.protein_row.completed` for a story milestone fact; it now reads "Story · Protein Row".

Open for the owner (HER-30): goals credit the attribute of the family that completed them ("Train for 45 min" by a run → Endurance; "Recover for 10 min" is Mindfulness by template, Endurance only if completed by a walk). Say whether goals should always credit their template's attribute instead.

Follow-ups built the same day (owner answers): the fight note card slides away on the next action; rest and recovery goals always pay Mindfulness, training goals pay where the session pays (HER-30, option A with the rest exception); PostHog rage-click detection off.
