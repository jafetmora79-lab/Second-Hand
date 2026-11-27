# Second Hand

A small 3D browser game: you run a second-hand and antique shop in a snowed-in mountain town. Townsfolk bring in objects; you pick each one up,
turn it in your hands, find the maker's marks, the damage and the tells of fakes with a loupe, then haggle. Sell to collectors, pay the rent.

**Play it in your browser: https://jafetmora79-lab.github.io/Second-Hand/**

Made for the OpenGame Game Jam #1 (Simulation & management, Best use of Meshy AI). Godot 4.3, Compatibility renderer, single-threaded web export.
Every object is meant to be a Meshy model made from a concept image, looked at closely from any angle.

- Design and schedule: `docs/DESIGN.md`
- Concept-image prompts for ChatGPT: `docs/CHATGPT_PROMPTS.md`

## Run
- Desktop: open the project in Godot 4.3 and press Play.
- Web: `godot --headless --export-release "Web" build/web/index.html`, then `python tools/serve_web.py` and open http://localhost:8060.
- Test in headless Chrome on the real GPU: `node tools/web_probe.mjs "http://localhost:8060/" 12 <out_dir>` (console, screenshots, fps).
- Publish: export as above, then push the contents of `build/web` (plus an empty `.nojekyll`) to the `gh-pages` branch; GitHub Pages serves it.
- Smoke test: `godot --headless -s tests/smoke.gd`

## Controls
In the shop, use the buttons. While inspecting: drag to turn the object, scroll to zoom, rest the loupe (the mouse) on a detail to read it.
