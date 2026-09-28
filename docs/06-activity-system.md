# 06 — Activity System

## Design goal
Support broad real-life behavior without presenting a giant tracker interface.

## MVP families
1. Strength
2. Cardio
3. Combat
4. Mobility / Recovery
5. Learning
6. Mindfulness

## Example mapping
- Weightlifting → Strength
- Calisthenics → Strength
- Running → Cardio
- Cycling → Cardio
- Swimming → Cardio
- Tennis → Cardio
- Boxing → Combat
- Kickboxing → Combat
- MMA → Combat
- BJJ → Combat
- Yoga → Mobility / Recovery
- Stretching → Mobility / Recovery
- Reading → Learning
- Studying → Learning
- Meditation → Mindfulness
- Breathwork → Mindfulness

## UI strategy
Do not expose the full taxonomy by default.

Log sheet should prioritize:
- recent activities
- frequent activities
- suggested activities
- search

## Logging modes
### Passive
Imported from Apple Health when permission/source supports it.

### One-tap/simple
Activity + duration + done.

### Detailed
Only when data creates user value. Strength training is the main MVP detailed workflow.

## Future-proofing
Specific activity records should remain specific even when mechanics use the parent family. This enables future specialized Personas, classes, analytics, or weighting without losing history.
