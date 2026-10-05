# 31 — Chapter one script

Every line in chapter one, who says it, and what triggers it. Generated from `Content/v1/bundle.json` (content 2026.10.05-6) and the onboarding prompts. Cairon and Chad Colossus are provisional names.

## Onboarding

### Awakening  `chapter.awakening`
**Trigger:** First launch, before character creation  
**Backdrop:** `backdrop.alley_awakening` · **then:** create_character

- **You:** Wha.. Where am I?
- **Cairon:** Ah good, you're awake.
- **Cairon:** That was a nasty uplink, one of the worst I've seen yet.
- **You:** ...Uplink?
- **Cairon:** Yes my child..
- **Cairon:** You've awoken in this, our digital world of Neo Tokyo.
- **Cairon:** When a human in the real world decides to take the Ascension challenge, you become **soul bound** to them.
- **You:** Soul bound? Sounds.. serious.
- **Cairon:** It is.
- **Cairon:** It means right now your survival depends on the determination of your human.
- **Cairon:** Their actions in the real world make you stronger here.
- **Cairon:** But also, their failures are your failures.
- **Cairon:** My human gave up on me a long time ago..
- **Cairon:** But I see something powerful in your bond...
- **Cairon:** Perhaps you could even reach Ascension one day!
- **You:** Ascension?
- **Cairon:** Ascension, yes. Grow strong enough and you can bend the very fabric of this world...
- **Cairon:** To ascend is to become powerful enough even to *escape* this digital world.
- **Cairon:** It's a lot, I know. We'll talk about it more.
- **Cairon:** ...Do you remember anything about your real, human self?

### Cairon's questions (onboarding steps, `OnboardingView`)
**Trigger:** each step of character creation, in this order

- **Cairon:** Start with the easy one. What did they call you?
- **Cairon:** {name}.. the name of a hero. Which of these is you?
- **Cairon:** I can barely see your face in the gloom down here.
- **Cairon:** Do you remember what looks right?
- **Cairon:** Pick how you most plan to develop your physical strengths.
- **Cairon:** Now tell me how you are most likely to build your mental strength.
- **Cairon:** How many days a week do you train?
- **Cairon:** Now, a question for the soul.. Why are you doing this?
- **Cairon:** Now, to make sure you and your human's progress are linked: let's connect this.
- **Cairon:** Who you are is clear to me now. It's time to seal the bond between you two.

### The bond  `chapter.first_training`
**Trigger:** End of onboarding, after “Seal the bond”  
**Backdrop:** `backdrop.alley_awakening` · **then:** home

- **Cairon:** That's it, then. The bond holds.
- **Cairon:** Your human has taken the challenge. From here, every step they take in their world is a step you take in this one.
- **Cairon:** Many humans neglect themselves. It's in their nature to give up.
- **Cairon:** Not this one. Not if I can help it.
- **Cairon:** You'd better get to training. I'll be with you all the while.

## Campaign beats
Each plays once, when its level is reached and the screen is quiet (no reward modal, level-up, stage, or unclaimed cache). An interrupted scene replays.

### Your room  `chapter.home`
**Trigger:** Level 2, automatic · room backdrop `backdrop.under_city.home_01`; unlocks `home_room`  
**Backdrop:** `backdrop.under_city.home_01` · **then:** room

- **Cairon:** I can already see you're getting stronger out there.
- **Cairon:** You're welcome to stay here. It's not much.
- **Cairon:** It was mine, once. Now it is yours. Come back here when you need to think, or change how you look to yourself.
- **Cairon:** Everything you earn down here ends up on these walls. Give it time.

### Protein Row  `chapter.protein_row`
**Trigger:** Level 3, automatic · Home scene becomes `backdrop.under_city.protein_row_01`  
**Backdrop:** `backdrop.under_city.protein_row_01` · **then:** return

- **Cairon:** Protein Row. Gyms, shakes, people who talk about nothing else.
- **Cairon:** You will like it. Everyone here is trying to become something.
- **You:** What is at the end of the street?
- **Cairon:** The Colossus Gym. We will get to that. Train first.

### Rumours  `chapter.rumors`
**Trigger:** Level 4, automatic  
**Backdrop:** `backdrop.under_city.protein_row_01` · **then:** return

- **Cairon:** They say the man who built the Gym never left it. They say he is still inside, still lifting.
- **Cairon:** They say a lot of things on this street.
- **You:** Is any of it true?
- **Cairon:** Enough of it. You are not ready for the door yet. Soon.

### The Gym opens  `chapter.gym_gate`
**Trigger:** Level 5, automatic · Home scene becomes `backdrop.colossus_gym.exterior_01`; daily quest becomes `quest.colossus_gym_01`  
**Backdrop:** `backdrop.colossus_gym.exterior_01` · **then:** return

- **Cairon:** Look at you. That is the first change, and it will not be the last.
- **Cairon:** The Gym's door is open to you now. It was not before.
- **You:** What is in there?
- **Cairon:** Everyone who ever wanted to be stronger. Some of them are still deciding why.

### The floor  `chapter.gym_floor_one`
**Trigger:** Level 6, automatic  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **Cairon:** Floor one looks like any gym. That is the point. Nobody notices when it stops being one.
- **You:** I can handle a gym.
- **Cairon:** Go on, then. Come back and tell me what you saw.

### Deeper  `chapter.gym_deeper`
**Trigger:** Level 7, automatic · daily quest becomes `quest.colossus_gym_02`  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **Cairon:** The lower floors are where the culture lives. It was a good culture, once.
- **Cairon:** Watch for the moment it tips. It always tips.
- **You:** Tips into what?
- **Cairon:** Into more. Only ever more.

### Chad Colossus  `chapter.colossus_reveal`
**Trigger:** Level 8, automatic  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **Chad Colossus:** You are new. New ones always look at the plates first. Look at me.
- **Chad Colossus:** I have not missed a day in eleven years. Not one. Do you know what that makes me?
- **You:** Strong.
- **Chad Colossus:** Strong. Yes. Say the other word. The one you are thinking.
- **You:** ...Alone.
- **Chad Colossus:** Get stronger. Then come and tell me I am wrong.

### The last floor  `chapter.final_approach`
**Trigger:** Level 9, automatic · daily quest becomes `quest.colossus_gym_03`  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **Cairon:** The last floor is his. He is not a monster. That is what makes this hard.
- **You:** What do I say to him?
- **Cairon:** Say what you are improving for. If you can answer that, you are already past him.

### What are you improving for?  `chapter.colossus_resolution`
**Trigger:** Level 10, the player taps “Face Chad Colossus” on Home · completes the chapter; teases `central_hill`  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **Chad Colossus:** Eleven years. Every plate on this floor has my hands on it. Tell me what you have.
- **You:** A room. A street. Someone waiting for me outside the screen.
- **Chad Colossus:** That is nothing.
- **You:** It is a reason. What is yours?
- **Chad Colossus:** ...
- **Chad Colossus:** I used to know.
- **Cairon:** That is the whole lesson, and he taught it better than I could. Everyone comes here to become stronger. Some forget why.
- **Cairon:** The Under City is behind you now. There is a hill above us, green and wired, where the running never stops. Central Hill. When you are ready.

## Quest end scenes
Play after the cache from that quest is claimed.

### After the floor  `chapter.gym_floor_end`
**Trigger:** Claiming the cache from `quest.colossus_gym_01` (Colossus Gym · the floor)  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **You:** Nobody down there leaves. They just keep going.
- **Cairon:** Motion is easy. Stopping is the skill. Remember that when the plates feel good.

### The logbook  `chapter.gym_deeper_end`
**Trigger:** Claiming the cache from `quest.colossus_gym_02` (Colossus Gym · deeper)  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **You:** There is a name in every logbook down there. The same name.
- **Cairon:** Chad Colossus. He built this place to get strong. He got strong. Then he kept building.

### Ready  `chapter.final_approach_end`
**Trigger:** Claiming the cache from `quest.colossus_gym_03` (Colossus Gym · the last floor)  
**Backdrop:** `backdrop.colossus_gym.interior_01` · **then:** return

- **You:** He is waiting. I think he wants to be asked.
- **Cairon:** Then ask. When you are ready, not before.

## Quest lines
Spoken by the hero on the quest card, departure screen, notification prompt and return.

### Under City  `quest.lower_district`
**Available:** from the start · **duration:** 240 min

- **Notification prompt (until the system prompt is answered):** Time to see if I can find anything useful around here. I'll be back in a few hours.
- **Subtext (departure screen):** This place is a MESS. I'll let you know if I find anything useful down here.
- **Depart:** The Under City at this hour. I will be back before the rain changes.
- **Depart:** Four hours. Do not wait up; do something useful instead.
- **Depart:** Goals done, so I go. That was the deal.
- **Away:** Somewhere below the overpass. Signal is bad.
- **Away:** Still walking. The city is longer than the map says.
- **Away:** Not back yet. Keep the light on.
- **Return (common):** Back. Nothing dramatic, a route I had not taken. It counts.
- **Return (common):** The district was quiet. I walked it anyway.
- **Return (uncommon):** Back. Someone down there knew my name before I said it. Odd.
- **Return (uncommon):** Found a stairwell that was not on any map. Noted.
- **Return (rare):** Back, and not the same. Something under the city looked at me and let me pass.
- **Return (rare):** There is a door down there with my name scratched into it. I did not open it. Yet.

### Protein Row  `quest.protein_row`
**Available:** after milestone `under_city.3.protein_row` · **duration:** 240 min

- **Notification prompt (until the system prompt is answered):** Protein Row is awake at this hour. Four hours; I want to hear what they say about the gym.
- **Subtext (departure screen):** Pill stores, an old gym, a man in sunglasses who never moves. Somebody here knows about Colossus.
- **Depart:** Protein Row. If the sunglasses man talks, I will listen.
- **Depart:** Four hours on the Row. Do your goals; I will do mine.
- **Away:** Outside the Test MAX place. Everyone in there is shouting about growth.
- **Away:** Still on the Row. The old gym's door is open and nobody goes in.
- **Return (common):** Back. The Row smells like whey and rain. I asked about the gym; people looked away.
- **Return (common):** Back. Walked the whole street twice. The sunglasses man nodded once.
- **Return (uncommon):** Back. A woman at the pill store said Colossus used to train at the old gym. Used to.
- **Return (uncommon):** Back. Somebody left a torn Colossus flyer on the crates. I kept it.
- **Return (rare):** Back. The old gym's owner said one thing: 'Everyone goes in wanting to be stronger. Some forget why.'

### Colossus Gym · the floor  `quest.colossus_gym_01`
**Available:** after milestone `under_city.5.gym_unlock` · **duration:** 480 min

- **Notification prompt (until the system prompt is answered):** The gym runs all night. Eight hours; I will come back with something.
- **Subtext (departure screen):** Iron, chains, and people who forgot what day it is.
- **Depart:** The front desk did not ask my name. Nobody here has one.
- **Depart:** Eight hours on the floor. Count the plates for me.
- **Away:** Somewhere between the squat racks. It does not end.
- **Away:** Still lifting. Everyone is still lifting.
- **Return (common):** Back. My arms are not mine. Someone down there has not left in a year.
- **Return (uncommon):** Back. A man gave me his old chalk and would not say why.
- **Return (rare):** Back. There is a door at the end of the floor that nobody looks at.

### Colossus Gym · deeper  `quest.colossus_gym_02`
**Available:** after milestone `under_city.7.deeper` · **duration:** 480 min

- **Notification prompt (until the system prompt is answered):** The gym runs all night. Eight hours; I will come back with something.
- **Subtext (departure screen):** Iron, chains, and people who forgot what day it is.
- **Depart:** Lower floor. The lights are red down there.
- **Depart:** Eight hours. If I do not come back, assume I am still at it.
- **Away:** Below the floor. The music stopped a while ago.
- **Away:** Chains. More chains than people now.
- **Return (common):** Back. The weights down there are not for lifting. They are for staying.
- **Return (uncommon):** Back. Found a logbook. Same name, every page, every year.
- **Return (rare):** Back. Someone whispered his name like it was a prayer. Chad.

### Colossus Gym · the last floor  `quest.colossus_gym_03`
**Available:** after milestone `under_city.9.final` · **duration:** 480 min

- **Notification prompt (until the system prompt is answered):** The gym runs all night. Eight hours; I will come back with something.
- **Subtext (departure screen):** Iron, chains, and people who forgot what day it is.
- **Depart:** The last floor. He is down there. I can hear the plates.
- **Depart:** Eight hours. Then it is him and me.
- **Away:** At the bottom. The air is heavy here.
- **Away:** He has not noticed me yet.
- **Return (common):** Back. He is ready. So am I, I think.
- **Return (uncommon):** Back. He asked why I came. I did not have an answer yet.
- **Return (rare):** Back. He is enormous, and he looked tired.
