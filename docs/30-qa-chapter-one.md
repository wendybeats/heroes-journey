# 30 — QA list: chapter one build (2026-10-05)

Build: branch `claude/tender-hamilton-d57cv9`, commit in the increment 28 entry of doc 20. `xcodegen generate && open HeroesJourney.xcodeproj`, run on a simulator or device. Reset the app (delete it) between full passes; the archive persists quest runs and story progress.

## A. Story director and chapter one
1. Fresh install → onboarding plays the awakening; after the bond, Home shows no scene replay (milestone 1 recorded).
2. Reach Level 2 (log activity; the dev cap is 40 XP/day plus goals) → the "home" chapter plays once the screen is quiet (no reward modal, no stage). The room button (house) appears in the toolbar after it finishes.
3. Kill the app mid-chapter → relaunch replays the same chapter; it never skips and never plays twice after finishing.
4. Levels 3–4 → Protein Row and rumours chapters, one per level, in order. Level 5 → gym gate chapter; the daily quest becomes Colossus Gym 01 (8 h).
5. Level 10 → no auto chapter; Home shows the story card "Face Colossus". Tapping plays the resolution with the Central Hill tease; the card disappears after; Colossus renders as a named stand-in portrait.
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
