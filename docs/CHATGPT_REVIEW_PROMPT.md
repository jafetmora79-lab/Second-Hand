# Prompt for ChatGPT: review Second Hand

Paste this into ChatGPT (a model that can browse GitHub). Paste its answer back to Claude to build from.

```
You are a senior game designer and writer reviewing a small browser game for a game jam (OpenGame Game Jam #1, Simulation & management, "Best use of Meshy AI"; closes 18 Dec 2026). The public repo is https://github.com/jafetmora79-lab/Second-Hand and the playable build is https://jafetmora79-lab.github.io/Second-Hand/ .

The game: you run a second-hand and antique shop in a snowed-in 1950s mountain town (the same world as our other game, Timberline). Callers ring an electric door; you see them on a porch camera and buzz them in or not. Sellers put an object on the velvet mat; you pick it up, turn it, and find the maker's marks, damage and the tells of fakes with a loupe, then haggle. Every kind of object comes in five versions and only one is real. Buyers come for what is on your shelves. Robbers may come from day 2. Rent of $600 is due on day 7. Engine: Godot 4.3, GDScript, Compatibility renderer, single-threaded web export.

Read these files first: README.md, docs/DESIGN.md, scripts/people.gd (customers and all their lines), scripts/items.gd (objects, clues, the five versions), scripts/main.gd (the day, the door, haggling, robberies), scripts/shop.gd (the room layout, with coordinates), scripts/shop_ui.gd (what is on screen).

Give me four things, concrete enough to implement straight away:

1. Better conversations. Rewrite every customer's lines in scripts/people.gd so each person has a distinct voice and a small story that unfolds over the 7 days (what they say on their first, second and later visits; how they react to a fair offer, a lowball, being turned away at the door, being caught with a fake). Add 2 or 3 short lines the player can choose to say during haggling (friendly, firm, suspicious) and how each customer reacts to each. Keep every line under 25 words, warm and a little wry, fitting a cosy snowy 1950s town. Give the result as GDScript dictionary entries in the same shape as People.FOLK, BUYERS and ROBBERS, so they can be pasted in, plus any new fields you need, explained.

2. A better shop layout. The room is 6 m wide (x -3..3), 5 m deep (z -4..1), 2.9 m high; the player stands behind the counter at z 0 looking toward -z; the door is at x -2.2 on the back wall, the big window at x 0.3..2.5 on the back wall. Suggest where the counter, shelves, display pieces, stove and decorations should go so the room reads well from the player's fixed view and the customers' walk from the door to the counter looks natural. Give positions in metres and say which existing models (assets/kit, assets/shop, assets/outside) to use and what new props (at most 6) are worth making, each with a one-line image prompt in the same style as docs/CHATGPT_PROMPTS.md.

3. A better "filter". Two parts: (a) a visual filter / post-processing look that makes the game instantly recognisable in screenshots and the jam's video, and is web-safe in Godot 4.3 Compatibility (no screen-texture mipmaps, no MSAA; a canvas_item or spatial shader is fine), described precisely enough to write the shader; and (b) a better way to filter customers at the door: what the player can notice on the porch camera, and how word of mouth, reputation or the shop's ledger could make letting the wrong people in a real decision across the week.

4. The five highest-impact fixes or features for the jam's judging, in order, each with why and roughly how.

Be specific to this code; do not give generic advice.
```
