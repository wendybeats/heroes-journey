# 45 · Notifications MVP: the echo checks in (HER-24, locked 2026-10-23)

Owner decisions 2026-10-23, after the Duolingo research (HER-24 comment): emulate Duolingo's machinery (behaviour-keyed timing, one a day, a copy pool with a recency rule, a hard stop after a week, a last note) and invert its lever. Duolingo works on loss (the streak dies). Here nothing is ever lost (CLAUDE.md rules 1 and 4), so the echo never threatens, it says what is true today. Narrative frame: the Linear document "Echo, System & the Watching City": the echo is first person, curious, vulnerable without being helpless; the System is terse and functional; neither guilts.

## Voice rules (locked)
- Daily check-ins come from the echo, the player's own character, in first person. Cairon never sends a push.
- Every line is true that day or it is not sent: it comments on how the echo feels, asks how the player feels, or notes something about the world the player has already unlocked. No generic lines, no activity-specific instructions.
- No line mentions days missed, counts of absence or anything lost. The last note of the lapse sequence is the only one that acknowledges silence, and it asks.
- Earned completions and unlocks are event-timed and exempt from the daily cap. System voice for unlocks and status; echo voice for discoveries.

## Categories
| Category | Voice | Trigger | Cap |
|---|---|---|---|
| Earned | Echo | quest return, cache unopened, a goal completed by a Health import while the app was closed, a level reached | event-timed, exempt |
| Unlocks and status | System | a story beat or area became available while the app was closed | event-timed, exempt |
| Daily check-in | Echo | once a day, 23 h after the last open, clamped to 08:00–21:00 local | one a day; lapse rule below |

## Contexts and the signals the app already has
Selection is context first, then the least recently used line in that context's pool (not reused within ten days). Contexts, in priority order:

| # | Context | Signal |
|---|---|---|
| 5 | The echo's own body | yesterday's facts by family (strength, cardio); a Health-imported session since the last open; the first session ever |
| 2 | Training day after a big one | yesterday's strain high (the ruleset's strain input) and today's primary goal is a training goal |
| 1 | Training day, fresh | yesterday light or rest; today's primary goal is a training goal |
| 3 | Rest or recovery day | today's primary goal is recovery, mobility or mindfulness, or the plan has no training goal |
| 6 | World and lore | gated by story flags (milestone ids, `quest.<id>.rare`); at most twice a week |
| 4 | Asking the player | fallback; at most twice a week |

Lines can only be scheduled ahead of time (local notifications), so tomorrow's line is computed when the app goes to the background with today's facts known; days further out use contexts 4 and 6, which need no fresh data. Every foreground cancels and recomputes the queue.

## Locked copy
**1. Training day, fresh**
- I'm feeling strong today. Let's get to training.
- Slept well, I think. Whatever you've got today, I'm up for it.
- I keep looking at the Gym sign. Let's earn a step closer.

**2. Training day after a big one**
- Yesterday reached me. I can still feel it. Let's go again, but smart.
- You went hard yesterday. I'm fine. Better than fine. Your call on today.

**3. Rest or recovery day**
- Yesterday was a big one. Let's take it easier today.
- Rest reaches me too. Walk, stretch, breathe. It all counts down here.
- Quiet day. The city's quiet too. I'll take it.
- I'm not going anywhere. Let your body catch up with what you did.

**4. Asking the player**
- How are you feeling today? I can only guess from down here.
- Tired or ready today?
- What does your world look like today?
- Is it raining where you are too?

**5. The echo's own body**
- Strength yesterday: My arms remember yesterday. Good memory.
- Cardio or a run yesterday: Legs feel different today. Whatever you did, it reached me.
- Health import overnight: Something arrived while you were asleep. A session. It counted.
- First session ever: That was the first time I felt you from out there. I want more of that.

**6. World and lore** (flag → line)
- before `under_city.3.protein_row`: The Undercity has secrets. I can feel them under the rain.
- before `under_city.3.protein_row`: There's a street past the alley that smells like protein and promises. Cairon won't let me past it yet.
- after `under_city.3.protein_row`: Someone on the Row swears the Gym's sign got bigger overnight. I'm starting to believe them.
- after `under_city.3.protein_row`: Test MAX put up a new "final formula" sign. The old one's still up behind it.
- after `under_city.3.protein_row`: The old man at the shake stand watched me today. Not unkindly. Like he was counting.
- after `under_city.5.gym_unlock`: The front desk doesn't keep a member list. That should bother me more than it does.
- after `under_city.5.gym_unlock`: I heard the lower floor hum. Nobody else did.
- after `under_city.8.reveal`: Colossus hasn't missed a day in eleven years. I'm not trying to beat that. I'm trying to understand it.
- after `quest.lower_district.rare`: I saw that door again today. Still closed. Still there.

**7. Lapse** (a day is unanswered when the app was not opened that day)
- Days 1 and 2 of absence: a normal check-in.
- Days 3 to 6: silence.
- Day 7, the last note: **I'm ready to get stronger. Where are you?** Then nothing until the player returns.

**8. Return** (in-app, first open after three or more days; never a push)
- You're back. Nothing you did went anywhere. It's all still here.
- I kept the lights on. Let's see what you brought back.

**Earned and System lines** (existing or to be written per beat; examples)
- Quest return: the quest's `return_line` (exists). Cache unopened next morning: "Still holding what I brought back. Open it when you're ready."
- Health-completed goal while closed: "That counted. Thirty minutes, logged."
- Unlocks: "YOUR ROOM IS OPEN", "DISTRICT ACCESS GRANTED // PROTEIN ROW", "COLOSSUS GYM // ACCESS GRANTED".

Pools 1 and 2 are thin (three and two lines); the recency rule may borrow from pool 5 on those days until the owner adds lines.

## Timing, caps, settings
- Daily check-in: 23 h after the last open, clamped into 08:00–21:00; never while the app is foregrounded (opening the app cancels the day's pending check-in and clears delivered ones).
- One check-in a day. Lapse sequence as above. Earned and System are exempt but never more than three notifications in a day in total.
- Quiet hours fixed 21:00–08:00 for the MVP (earned notifications outside the window are delivered at 08:00).
- Settings → three toggles: Earned, Check-ins, World and unlocks. Default on once permission is granted.
- Permission: unchanged, asked at the first "Begin quest" with the echo's line (doc 24). No new prompt.
- Deep links: quest return → the cache; unlock → the beat; check-in → Home. `userInfo` carries the target; the app resolves it on launch and on tap.

## Technical shape
- `NotificationScheduler` next to `QuestNotifications`: one identifier per kind and day (`checkin.<day>`, `earned.<kind>.<id>`, `unlock.<milestone>`, `lapse.last`), queue recomputed on every foreground/background transition; iOS allows 64 pending.
- Content in the bundle: `notifications.checkins[]` with `context`, `requires_flag` / `before_flag`, `line`; earned and unlock lines on the quest, goal and milestone entries. No line in code.
- Context evaluation is pure (facts in, context out) in HeroDomain, tested; scheduling is the app's.
- Analytics (HER-6 events): `notification scheduled` (kind, context), `notification opened` (kind, context, hours since delivery), `notification first action` (what the player did within two minutes of the open). Delivery is not observable without a service extension; skip for the MVP.

## Acceptance
- A player who trains every day sees a different, true line each morning for two weeks; a player on a recovery day never sees a training line.
- A player who stops opening the app gets two check-ins, four days of silence, the last note on day 7, and nothing after.
- Opening the app before the daily time means no check-in that day.
- Quest return, unlock and Health-completed goal arrive when the app is closed and deep-link correctly.
- Toggles stop their category; quiet hours hold.
- Device run by the owner with the dev clock (day offset) to step through the week.
