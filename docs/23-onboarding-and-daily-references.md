# 23 — Onboarding and daily-system references (2026-10-02)

Owner-supplied competitor screenshots under `assets/references/2026-10-02/`. References for structure and pacing, not for tone or visuals; doc 22 sets our tone (aspirational, RPG, dry) and doc 19 the look.

## Finch onboarding (batch 1)

| Screen | Pattern | Our equivalent |
|---|---|---|
| 01 hatch | The companion exists before any question; "You hatched a birb" | Awakening scene with the hoodie character before the name is asked |
| 02 trait choice | One decision per screen, large tappable rows, single Next, no scrolling form | Split the current onboarding into one screen per choice: name, body, hair, hair colour, skin, then interests |
| 03 stat feedback | The answer is reflected on the character at once ("+4.9 Logic") | Choosing interests nudges the matching attribute and shows the same "+n" badge Home uses |
| 04 starter plan | The companion proposes a short, easy plan at the end | The first day's 2–3 goals generated from the answers, framed as the character's ask |

Also noted: the character speaks in one short bubble per screen; progress through onboarding reads as story, not setup.

## Finch home, reward and adventure (batch 2)

Owner notes, verbatim: "a blue 'setting the stage' screen (could be similar to our transition between backdrops/environments)"; "home screen with tasks, experience, and character above. They use a lot more of the top of space, bleeding off the screen which could give us more real estate"; "a goal or reward sequence - meeting a criteria"; "the adventure screen, after user goes on adventure. Note character sprite walks and screen moves from right to left, imitating movement". Also from batch 1 discussion: "I do like the stat feedback, where the user earns some form of xp or stat increase before they hit home screen."

| Screen | What Finch does (observed) | Our equivalent |
|---|---|---|
| 05 setting the stage | Flat single-colour full-bleed screen, "DAY 1 / Happy Thursday!", a framed illustration, one line of instruction ("Help Pumpkin gain full energy today so he can go on an adventure"). No chrome, one tap to continue | Environment transition: flat navy flood, day counter + date, one line of story, one tap. Reuse the Ascension takeover's flood/reveal timings rather than inventing a second motion language |
| 06 home | Backdrop fills the top ~25% and bleeds off the screen; character stands on the ground line with nothing above it but a menu glyph. Below: energy meter card ("1st Adventure 0 / 15"), goals header ("7 goals left for today!"), goals grouped by time of day ("Start the day"), each row = icon, title, small reward number, single large check. Six-tab bar | Home v2: scene bleeds under the status bar with the character at bottom-centre (already 2× on the alley backdrop); adventure/energy meter directly under the scene; today's 2–3 goals as rows with one check each; stats and History move down or into their own tab. No six-tab bar; keep tabs to Home, Log, History/Stats |
| 07 reward sequence | Same scene, meter snaps to "MAX" with the goal icon lit, confetti, headline + one sentence ("Pumpkin munched on Corn and energized for Day 1"), a reveal card "Pumpkin got +138 Rainbow Stones", top-right wallet count, single Continue | Energy-full moment: meter fills to MAX (gold), one line in the character's voice, "+n XP" reveal using the existing CountingText/DeltaBadge, then Continue. Same modal pattern as the existing reward modal, no new motion primitives |
| 08 adventure started | Scene becomes a side-scroller: character walks in place, background scrolls right→left (parallax: far trees slower than ground props). Under it: "New adventure started!", a dotted path from the pack icon to a "?" reward icon, and a countdown ("completes today's adventure in 7:59:54"; an 8 h adventure). Single Got it! | Adventure-departed state: walk clip from the kit (hoodie has one; suit needs confirming), backdrop scrolled on a TimelineView with two layers, dotted path + "?" reward slot + countdown. Confirms the async loop in doc 22; duration is the owner's call (doc 22 suggests 4 h, Finch uses 8 h) |

Numbers worth keeping: Finch's energy meter is 15 units with ~5 per goal, so three goals fill it; the full-meter payout (138 stones) is large relative to per-goal numbers because it is cosmetic currency, not progression. Our goal XP stays small and flat per doc 22; the meter can still fill from three goals.

## Decisions carried into the build
- Onboarding is a sequence of single-focus screens, each with the character present and one line of speech.
- Interests collected: primary (fitness family), secondary (learning or mindfulness), training frequency, motivation. These seed daily goals and the first attribute nudge.
- No custom plan beyond the daily goals.
- Home v2 layout: scene bleeds off the top, meter under it, goals under that, stats below or in History.
- A "setting the stage" full-flood screen opens each day / environment change and reuses the Ascension flood timings.
- Adventure departure shows a walking character over a scrolling two-layer backdrop with a countdown and a hidden reward slot.
- Energy-full reward reuses the existing reward modal pattern with the meter at MAX.
