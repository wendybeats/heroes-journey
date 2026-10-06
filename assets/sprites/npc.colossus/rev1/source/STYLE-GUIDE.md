# Shared sprite style

## One world pixel scale

The protagonist uses a 64×128 logical cell and stands 111 pixels tall. Colossus uses a larger 96×176 cell and stands 156 pixels tall. Both characters must use the **same integer display scale**: one art pixel on Colossus is the same screen size as one art pixel on the player. His larger cell provides his stature without giving him finer detail.

Use nearest-neighbor filtering. Do not stretch either image to a card's size, use smoothing, or squeeze every character into the player's cell. Dialogue portraits are a separate asset class and can retain more face detail.

## Rendering this sprite

Edit logical/colossus-sprite.png at 96×176. The main PNG is its exact 8× enlargement (768×1408). Use the provided palette and binary alpha. The foot contact row is 167, with proposed pivot (48,167). The preview aligns this with the player's contact row 122.

## Pixel language

Keep broad shadow masses and a few purposeful creases. No individual beard hairs, rust speckles, tiny fabric weave, smooth gradients or fine outlines. Use small bright marks only for chalk, chain and tracker. Retain the muted brown skin and deep navy shadows from palette.json.

At this scale the tank uses the existing gym logo's barbell emblem, and the plate uses a compact 100 mark. Full lettering belongs in the close-up or item artwork; never increase sprite density to force it in.

## Identity and equipment

Keep the left-facing, receding-haired, grey-stubbled, enormous but human Colossus. His expression is calm and weary. The right hand (screen-left, without tracker) grips the top outer rim of the 100 KG plate. It hangs behind his trouser leg and is approximately 20% larger in diameter than v4, subject to whole-pixel rounding. The short neck cable disappears under the shirt collar. Forearm implants, tracker and chain weight belt remain.
