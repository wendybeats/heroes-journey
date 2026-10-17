# 40 — Play-through notes, triaged (owner raw notes, 2026-10-17)

The owner's first full run on a real iPhone, from onboarding to the Colossus fight, sorted into what is clear enough to build, what is a mechanic or world decision, and what needs fleshing out first. Measured against doc 34 (the build map) and the V2 fight brief (doc 20 increment 56).

Three of the notes are confirmed bugs in the code as it stands, not impressions:
- **Ascension dev picker does nothing on Home.** The Home scene reads the tier from the level's evolution, not from `ascensionTier`, so the dev override only shows in the clash, the fight and the departure (`HomeView.swift` scene card).
- **Hair jumps from wolf cut to a short cut on the body switch.** The two bodies share no hair ids except bald, and the fallback takes the second style of the new body's list. Wolf cut is the fourth male style; blunt is the second female one.
- **Steps never appear in history.** Steps are read as a daily total for the steps goal and are never a fact, so nothing is logged and nothing is shown. The "0 XP" overlay was something else: a Health workout under the minimum duration or outside the credit window shows a receipt with 0 XP and no label. Needs one device log to say which.

## A. Clear and actionable: three builds

### Build A1, bugs and small UI (one push)
| # | Note | Change | Done when |
|---|---|---|---|
| 1 | Ascension dev tests do nothing | Home scene reads `state.ascensionTier` like every other screen | The dev picker changes the idle on Home |
| 2 | Wolf cut becomes short cut on body switch | Map the hair style by position between the two bodies (male 4th → female 4th) and keep the colour | Wolf cut → ponytail, buzz → blunt, medium → long, bald → bald |
| 3 | Physical selection: icon and colours beside each activity, not above | `AttributeGlyphs` row moves into each `ChoiceRows` row as a trailing glyph in the attribute colour | Each option carries its own glyph |
| 4 | Tapping a goal opens the wrong log panel | A goal tap opens the log sheet with the activity preselected from the goal's rule (its family, the first activity type in it); manual goals keep the tap-to-complete | "Read for 10 min" opens the sheet on Reading |
| 5 | After logging, Home is half-scrolled | Scroll to top on sheet dismissal before the receipt and the level-up play | The level bar is on screen when the numbers move |
| 6 | Quest notifications: no line after the prompt | One line under the enable button, Cairon's voice: "I'll let you know when I'm back." (content, `quests[].notification_prompt` already exists; add `notification_confirm`) | Shown once the permission has been answered either way |
| 7 | Dialogue portrait too big | 200 pt → 160 pt, frame kept (V2 P2-9 went too far) | Owner judges on device |
| 8 | "New area unlocked" during the cutscene | The unlock toast becomes a banner on the story scene's first beat ("New area · Colossus Gym"), so the player knows why the scene is playing; the Home toast stays | The banner shows at the top of the scene for 2.5 s |
| 9 | Steps: see why "0 XP" and where steps went | Diagnostic first (one device log of the import), then: a steps row in Today and History ("8,622 steps · counted for the walk goal"), never a fact and never XP (steps credit policy is still open in doc 24) | Steps are visible without inventing a fact |
| 10 | Sign in after character creation | Placeholder screen only, behind the accounts work (doc 34 Stage 1.3 item 5): "Sign in with Apple" and "Continue as guest", guest is the only live path | Nothing to build until the backend lands; the slot in the flow is reserved |

### Build A2, ceremonies (one push each, owner reviews on device)
| # | Note | Change | Done when |
|---|---|---|---|
| 11 | Bond moment: pauses, glow, animation, show why "+6 cardio-focused" | A sequence on the feedback step: the character glows up over ~1.2 s, the four attributes count in one at a time with a line each ("+6 Endurance · from your cardio", "+4 Mindfulness · from your interest"), a pause, then the seal button. Copy from `bond_grant` and the family → attribute weights, so it says why | The owner reads the reason without the caption |
| 12 | Ascension moment: much longer, a manual continue | Replace the takeover's timing: rise slowly while the glow builds (~2 s), tier-colour lightning strikes, eyes light, the figure is lost in white, one flash, the ascended idle with the tier name, then hold with the new look visible and a Continue button; Reduce Motion skips to the hold. Doc 32/38 own the look, this is the timing and the hold | Nothing advances until Continue |
| 13 | Cairon before the Face Colossus card | A one-beat scene the first time the beat is offered ("You know what's down there. Are you ready for this?"), then the card. Content: `milestones[].offer_chapter`; the director plays it once and records it | The card never appears cold |
| 14 | Colossus encounter: "small work especially at start" | Held for the owner's specific notes; the start sequence (entrance, first telegraph, the tutorial line) is the candidate | Owner notes |

### Build A3, home tour after an action (day-one Health)
| # | Note | Change | Done when |
|---|---|---|---|
| 15 | Imported XP: play the home tour after the user's next action, not the next day | The day-one hold (`healthGraceDay`, doc 20 increment 54) releases on the first thing the player does by hand that day (a goal tap, a logged session, a challenge), instead of at the next day's stage. The welcome card stays | A player who imports Level 3 sees the home scene after their first tap, like everyone else |

## B. Mechanic changes (decisions, then builds)
| # | Note | What it means | Status |
|---|---|---|---|
| 16 | Colossus Gym at Level 5 came two days after Protein Row because of Health; move it to Level 7 minimum | The chapter's ten beats sit on ten levels. Moving the gate to 7 puts gym_unlock 7, enter 8, deeper 8, reveal 9, final 9, boss 10 (two beats a level is already allowed) or drops a beat. The owner is rewriting the script and triggers anyway (D below), so the re-band belongs to that pass. doc 39's run says the chain, not the levels, sets the pace for most players | Decide with the script |
| 17 | Daily goals should reflect what the user wants to do; "play 20 minutes of music" is useless for most | Onboarding asks two more things: "what do you want to do more of" (a multi-pick over the families and interests) and "what do you have a hard time doing". The generator filters the secondary and small-win pools to the picked interests and weights the hard thing up on rest days. Templates that need an instrument or a specific hobby get an `interest` tag and are never offered without the pick. Future: user-authored goals (doc 24 backlog) | Build after the questions are approved |
| 18 | Goal descriptions straightforward, not cryptic | A content pass over `goal_templates[].lines`: the title says the task, the line says why or how, no riddles. The story lines (doc 33) stay rare and are the one place for voice | Copy pass, owner reviews in the inventory |
| 19 | Know the user's rest and training days; grow into "Wendell trains MWFS, lifts and runs, rests Sunday, could be pushed to a hike" | Today: a fixed weekday pattern from the declared frequency. Next: the pattern learns from the log (a day with a session on three of the last four weeks is a training day) and the plan uses the learned pattern; the family mix per weekday feeds the primary pool. Later: the push (a rest-day nudge when the week is light). Doc 34 Stage 2 "the outside world" | Design doc first |

## C. World changes
| # | Note | What it means | Status |
|---|---|---|---|
| 20 | Dialogue is wooden and cryptic in places; an overview is needed so the points weave together | Owner writes the overview (the arc, who knows what when, what each beat must land). Then a rewrite pass over `story_chapters` against it, with the inventory artifact for review | Owner first |
| 21 | Progression out of turn: a reveal about Colossus can come after he is established | The trigger audit: for each beat, the facts it assumes and the facts it reveals, checked against the order the director can play them in (levels, quests, the day-one hold, Health jumps). `Tools/check_chapter.py` can enforce "a beat that reveals X never plays after a beat that assumes X" once the assumptions are tagged in content | Owner's script pass, then the gate |
| 22 | "Every time I came back weaker" / "stronger than what?" does not follow | A line fix in `chapter.colossus_reveal` (or wherever the exchange lives), part of the rewrite | With 20 |
| 23 | Real things (activities, places) described plainly; game things (items, characters) may keep their voice | A rule for the copy pass: activity types, goal titles, Health labels and place names are informative; items, log pages and characters keep flavour | With 18 and 20 |
| 24 | Character backgrounds look odd in creation | The alley backdrop behind the creation sprite; likely the gradient mask against the 360 pt scene. Needs a screenshot to say what "odd" is | Screenshot |

## D. Questions for the owner
1. Gym at Level 7: re-band the chapter now (two beats on 8 and 9) or wait for the script overview? My recommendation: wait, and fix it in the same pass as the trigger audit.
2. Goal personalisation (17): are the two onboarding questions right, and is a multi-pick over families and interests enough for v1, or do you want free text?
3. Ascension (12): fixed timing or tap-through? "Manual continue" at the end is clear; should the lightning and whiteout also wait for taps?
4. Steps (9): visible as a row with no XP (my proposal), or do steps earn something beyond the walk goal? Doc 24's open question.
5. Bond feedback (11): show the four attributes or only the two that moved?
6. The "0 XP" receipt: which workout was it (type, length, date) so the diagnostic is one lookup?

## E. To do or flesh out, in order
1. **The script overview and trigger audit** (20, 21, 22, 16). Everything narrative waits on it, and it fixes the out-of-turn reveal and the gym pacing together. Owner's.
2. **Build A1** (bugs, small UI, log routing, scroll, banner, notification line, portrait size). Small, testable, no decisions needed.
3. **Build A3** (home tour after the first action). One rule change in the day-one hold.
4. **Build A2** ceremonies: bond, then Cairon's pre-boss beat, then the long Ascension. Each needs the owner on device.
5. **Goal personalisation v1** (17, 18): the two questions, the interest tags, the plain-language copy pass. Reviewed in the inventory artifact.
6. **Training-day model** (19): design doc, then the learned pattern, then the push. Doc 34 Stage 2.
7. **Habit push** (notifications, smart triggers, schedule): the highest-leverage item and the least defined. Needs the training-day model first, then a notification design (what, when, how often, what Cairon says). Doc 34 Stage 2 and 3.
8. **Fight start polish** (14) and the tutorial: after the owner's specific notes.
9. **Sign in** (10): with accounts, doc 34 Stage 1.3 item 5.

## F. Against doc 34 and the V2 brief
- Already built and matching a note: the day-one Health welcome (the note asks for a different release trigger, A3), the dialogue layout (V2 P2-9; the note asks for a smaller portrait), the fight (V2 checkpoints 1–3; "very good", small work at the start).
- Already queued in doc 34 and confirmed by a note: accounts and sign-in (Stage 1.3), copy reviewed in the inventory (item 7), the fight tutorial and the story around it (queue item 1), analytics and notifications (Stage 1.3).
- New to the map: goal personalisation (17), the training-day model (19), the habit push (the "biggest win" line), the trigger audit as a gate (21), the long Ascension and the bond ceremony (11, 12), Cairon's pre-boss beat (13). Added to the doc 34 queue.
- Doc 39's finding stands beside these notes: the quest chain, not XP, paces the chapter, and the quest unlock rule is still the owner's call.

## Owner answers (2026-10-17)
1. Gym at Level 7: in the script pass. The two-day jump is an edge for players with a lot of Health history.
2. Goal personalisation: two questions are enough. The answers must be general categories, not activities: "staying organised" spawns cleaning, writing, planning; "going to bed earlier" spawns reduced screen time, bedtime. Three to five categories, multi-select, and a picked category makes its group of tasks appear *more often*, never exclusively: a player who did not pick organisation can still get "make your bed this morning" at a reduced likelihood. Strategy to be worked out before building.
3. Ascension: the whole sequence (rise, lightning, eyes, whiteout, flash, the reveal) plays on its own; the tap at the end only means "seen it, continue".
4. Steps earn XP, carefully: MVP caps step credit at about 40 XP a day. Later it scales so frequent walkers earn normally and a rare walker's 10k-step day is a big moment.
5. Bond feedback: only the two attributes that moved.
6. The "0 XP" receipt: the owner will watch it. Reading from the code: steps never produce a receipt (they are a daily total for the walk goal, never a fact), and no milestone carries a reward, so a zero-XP "Logged" receipt can only be an imported Health workout. The most likely one is an Apple Watch auto-recorded walk that arrived after the day's 120 XP cap was spent: the engine priced it at 0 and the receipt borrowed the cap copy ("you've gone over your limit"). Under strain (increment 57) the same walk now credits at the band rate, so the message disappears on its own. "Not in history for today" is consistent with a walk that started before midnight and sits under yesterday. Build A1 adds the source to history rows ("Apple Health · Walking · 23 min") so the next ghost names itself, and the zero-XP copy is limited to activity receipts.
