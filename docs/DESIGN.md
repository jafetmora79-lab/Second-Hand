# Second Hand

A small 3D browser game for the OpenGame Game Jam #1 (closes 18 Dec 2026, 11:59 pm PT). Genre: Simulation & management. Sponsor track: Best use of Meshy AI.

## Pitch
You run a second-hand and antique shop in a snowed-in mountain town. Every day townsfolk come in with something to sell. You pick each object up,
turn it in your hands in 3D, and look closely: maker's marks underneath, cracks, missing parts, a signature that is not quite right. Then you name a
price, haggle, and decide: buy it, restore it at the bench, or turn it away. Sell to collectors, pay the rent each week, and follow the trail of one
rare piece through the town's past.

## The loop (one day, about 5 minutes)
1. Morning: the shop opens. The rent board says how much is due on Sunday.
2. A customer comes to the counter with an object and a story.
3. Inspect: the object sits on a velvet mat under a lamp. Drag to turn it, scroll to zoom, hover the loupe over it to find clues
   (marks, damage, signs of a fake). Each clue found changes what you know about its value.
4. Appraise: your estimate is shown as a range that narrows as you find clues.
5. Haggle: the customer asks a price; you counter. Their patience drops with each round. Push too hard and they leave; pay too much and you lose money.
6. Some days a collector comes in looking for something specific: sell from your shelves.
7. Evening: the till is counted. Weekly rent on day 7.

## Depth
- Clues have meaning: a maker's mark sets the base value, damage lowers it, a forged mark means a fake worth almost nothing.
- Restoration at the bench (polish, glue, replace a part) for a cost and time; restored items sell higher.
- Customers have personalities (patient, proud, desperate, shady) and come back.
- A storyline: the "Harlan music box" and other pieces of an old family's estate surface over two weeks; finding the truth ends the game.

## The Meshy angle
Every object is a Meshy model generated from a concept image, made to be looked at closely from any angle with a camera the player controls. The judges'
wording for the Meshy track: "3D models generated for the game that hold up under a camera you do not control." That is the whole game.

## Web-first rules (learned from Timberline)
- Godot 4.3, Compatibility renderer, single-threaded web export.
- No screen-reading shaders (no hint_screen_texture with mipmaps), no glow; MSAA off on the web.
- Audio buses declared in default_bus_layout.tres, never created at runtime.
- Ship our own fonts (the browser cannot use the PC's fonts).
- One room and a window view: small, fast to load (target: playable in under 10 s, under 50 MB).
- Test in headless Chrome every day (tools/web_probe.mjs).

## Schedule
- Week 1 (to 3 Dec): the shop, inspection, clues, appraisal, haggling, one full day, playable in the browser; first Meshy objects in.
- Week 2 (to 10 Dec): 25 to 30 objects, 5 customers with personalities, restoration, collectors, the week and rent, the story.
- Week 3 (to 18 Dec): polish (sound, light, juice), balance, playtests, submit by 16 Dec.
