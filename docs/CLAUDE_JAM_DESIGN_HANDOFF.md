# Second-Hand — Claude design handoff
## Mission
Read README.md, docs/DESIGN.md, docs/CHATGPT_PROMPTS.md and scripts/people.gd, items.gd, main.gd, shop.gd, shop_ui.gd, outside.gd. Reconcile this review with current code before implementing. OpenGame Game Jam #1: simulation & management / best use of Meshy AI; deadline Dec 18 2026, aim Dec 16. Godot 4.3 Compatibility, single-threaded web. Preserve existing assets and gameplay. Snowy 1950s mountain antique shop, inspect, haggle, electric door, porch camera, buyers, robbers from day 2, $600 rent day 7, $500 starting cash. Proposed setting 1956. Tagline: Everything has a history. Not everything has the history you're told.
## 1. Dialogue and narrative
Keep existing IDs, colors, heights, economics and dictionary compatibility. Add visit-indexed greetings, final, door_reject, fake, friendly, firm, suspicious, rumor fields. Buyers retain string hello and add visits and empty. Below is reconstructed dialogue content for integration, not a verbatim transcript of the earlier review.
```gdscript
const DIALOGUE = {
 "trapper": {
 "visits": ["Morning. Found this in my brother's cabin. Thought you might know what it's worth.", "Been patching the roof. Funny what turns up under old floorboards.", "Cabin's nearly ready for winter. You treated me square last time.", "My brother would have liked this shop."],
 "accept":"Fair enough. It'll buy a few nails.", "counter":"Could you come up a little? Timber isn't cheap.", "final":"That's as low as I can go.", "leave":"I'll keep it a while longer.", "insult":"I may be old, but I can still count.", "door_reject":"Right. I'll try again another day.", "fake":"Well, I'll be. He must have been fooled too.", "friendly":"You're a decent sort.", "firm":"A shop has to make a living, I suppose.", "suspicious":"Found it where I said I did.", "rumor":"Harlan used to buy things from up the mountain."
 },
 "collector": {
 "visits":["I have something rather unusual. I trust you know your antiques.", "I've been examining the Harlan estate. Some pieces are rather questionable.", "Someone has been passing reproductions off as originals.", "I owe you an apology. Your eye is better than I expected."],
 "accept":"A reasonable arrangement.", "counter":"Surely you appreciate its provenance.", "final":"I won't entertain anything lower.", "leave":"Perhaps another dealer will appreciate it.", "insult":"How extraordinarily rude.", "door_reject":"I shall remember that.", "fake":"Let me see that mark. Good heavens.", "friendly":"Courtesy is becoming rare.", "firm":"Very well. Business is business.", "suspicious":"Are you questioning my judgment?", "rumor":"Compare the estate marks carefully."
 },
 "widow": {
 "visits":["My husband kept this for years. I thought someone else might enjoy it.", "I've been sorting his things. The house feels rather empty.", "It's easier knowing these things won't simply be thrown away.", "Thank you for giving his belongings another home."],
 "accept":"Thank you, dear.", "counter":"Could you manage a little more?", "final":"I think that's the least I can accept.", "leave":"Perhaps I'm not quite ready.", "insult":"I didn't come here to be treated like that.", "door_reject":"Oh. I'm sorry to bother you.", "fake":"He always thought it was real.", "friendly":"That's very kind of you.", "firm":"I understand.", "suspicious":"It was his. That's all I know.", "rumor":"My husband knew Harlan before the estate sale."
 },
 "kid": {
 "visits":["Hey! How much would you give me for this? I'm saving for a sled.", "I'm nearly halfway there!", "Found another thing in the attic. Mum said I could sell it.", "Got my sled! You should see how fast it goes."],
 "accept":"Really? Thanks!", "counter":"Aw, just a little more?", "final":"That's my lowest. Promise.", "leave":"I'll ask somewhere else.", "insult":"Hey! I'm not stupid.", "door_reject":"Oh. Okay.", "fake":"Wait, it's not real?", "friendly":"You're the best!", "firm":"Fine, fine.", "suspicious":"I didn't steal it!", "rumor":"Saw someone carrying boxes near the old estate."
 },
 "drifter": {
 "visits":["Got anything for this? Just need enough to get through the night.", "Still stuck here. Roads aren't getting any better.", "The lodge might have some work for me.", "Got a job at the lodge. Thought I'd stop by and thank you."],
 "accept":"That'll do.", "counter":"Come on. I need a little more.", "final":"That's all I can take.", "leave":"Forget it.", "insult":"You don't know a thing about me.", "door_reject":"Yeah. Figures.", "fake":"Didn't know. Bought it off someone else.", "friendly":"Not many people talk to me like that.", "firm":"All right.", "suspicious":"Why all the questions?", "rumor":"Someone offered me a box of estate pieces for next to nothing."
 }
}
const BUYER_DIALOGUE = {
 "collector_b":{"hello":"Mr Pell. I'm cataloguing some local collections.", "visits":["I'm looking for instruments and watches.", "Have you come across any Harlan pieces?", "Your stock has helped fill several gaps.", "The catalogue is nearly complete."], "empty":"Nothing for my collection today.", "accept":"Excellent. I'll take it.", "counter":"A little steep for my budget.", "leave":"Another time, perhaps.", "fake":"I cannot catalogue a reproduction as an original."},
 "decorator":{"hello":"Jo, from the lodge. We're reopening soon.", "visits":["I need household pieces with a bit of character.", "The lobby is coming together.", "Guests keep asking about our antiques.", "Come up to the lodge sometime."], "empty":"Nothing quite right for the lodge today.", "accept":"Perfect for the lodge.", "counter":"I've still got rooms to furnish.", "leave":"I'll check back.", "fake":"I can use a reproduction if it's priced honestly."}
}
const ROBBER_DIALOGUE = {
 "robber":{"hello":"Open up. I've got something to sell.", "door_reject":"Fine. Your loss.", "suspicious":"Just open the door.", "leave":"Forget it."},
 "drifter":{"hello":"Can we talk inside?", "door_reject":"All right. I'm going.", "suspicious":"I'm just trying to get by."}
}
```
Existing seller economics belief/floor/patience: trapper .8/.7/4; collector 1.35/.88/2; widow .7/.6/5; kid 1.1/.5/3; drifter 1.25/.45/2. Pell instruments/watches pays 1.35 patience 3; Jo household/curios/folk art pays 1.25 patience 3. Preserve existing economics until balance tests. Player choices once per encounter: “Let's find a price we're both happy with.” / “I have to leave room for a profit.” / “Tell me where this really came from.” Fake confrontation only after discovering evidence. Track trust, rejected, fair_deals, lowballs, fake_exposed, last_day, rumor_heard, visits; merge defaults into old saves. Chronological greetings based on visits, gate story milestones by actual events (e.g. Toby's sled, drifter employment). Seven-day optional Harlan mystery: Amos repairs late brother's cabin, Vale investigates estate fakes, Holt lets go of husband's possessions, Toby saves for sled, drifter seeks lodge employment, Pell catalogues estate, Jo reopens lodge. Rent remains primary victory.
## 2. Room layout
Room x -3..3, z -4..1. Camera (0,1.62,.35) looking -z. Door x -2.2 rear wall; window x .3..2.5. Proposed coordinates (x,y,z), verify actual mesh origins and collisions:
|Object|Position|
|---|---|
|Glass counter|(0,0,-.62)|
|Inspection mat|(0,1.025,-.5)|
|Customer|(0,0,-1.45)|
|Left shelf|(-2.65,0,-1.85)|
|Right shelf|(2.65,0,-2.05)|
|Stove|(-.77,0,-3.55)|
|Firewood|(-.13,0,-3.62)|
|Window bench|(1.4,0,-3.65)|
|Barrel|(2.55,0,-.85)|
|Lantern|(0,2.2,-1.8)|
|Rug|(0,.008,-2.25)|
|Wall clock|(-.65,2.15,-3.84)|
|Ledger|(-.85,1.025,-.45)|
|Lamp|(.85,1.025,-.48)|
|Monitor|(-.93,1.025,-.75)|
Existing assets: shop/counter_glass.glb, shelves.glb, FURN_stove.glb, HK_log_pile.glb, HK_barrel_crate.glb, TOOL_axe.glb, HK_lantern.glb; verify paths. Stove currently outside view at (-2.4,0,.4). Walk route ENTRY_CLEAR (-2.2,0,-3.05), AISLE_TURN (-1.55,0,-2.45), COUNTER_APPROACH (0,0,-1.85), customer spot; reverse on exit. Speed 1.15 m/s. Alternate shelf slots left/right, prioritize y .81 and 1.28. Permanent reference pieces for comparison.
### Maximum six new Meshy props
Common prompt suffix: single standalone low-poly 3D game asset, chunky readable geometry, subtle pixel-art texture, muted warm palette, 1950s snowy mountain antique shop, three-quarter view, white background, no scenery, no text, whole object visible.
1. Brass banker's lamp, green glass shade, curved brass stem, weighted base.
2. Open worn leather ledger, cream pages, faint ruled lines, no legible text.
3. Small 1950s walnut CRT security monitor, rounded glass screen, analog knobs, no modern logos.
4. Wooden pendulum wall clock, cream dial, brass pendulum, glass front.
5. Flat burgundy and cream woven rug, simple geometric border, subtle wear.
6. Low dark wooden display bench, simple legs and worn top.
## 3. Visual direction: Winter Amber
Illustrated winter postcard, warm walnut and amber inside against cold blue outside. Palette #50392B #E4B575 #702E3D #91B4CA #E7E5D8 #262B30. Room light .85 color (1,.86,.70), inspection 2.5 (1,.94,.83), window .85 (.65,.80,1), ambient .4, stove .9. Verify exposure and legibility. No photorealism. Avoid expensive effects.
Suggested lightweight overlay shader, CanvasLayer below UI, no screen texture:
```glsl
shader_type canvas_item;
uniform float inspection = 0.0;
void fragment(){
 vec2 p=UV-vec2(.5);
 float edge=smoothstep(.25,.72,length(p));
 float grain=fract(sin(dot(floor(UV*vec2(640.,360.)),vec2(12.9898,78.233)))*43758.5453);
 float a=(edge*.18+grain*.025)*(1.0-inspection*.75);
 COLOR=vec4(mix(vec3(.25,.13,.07),vec3(.08),edge),a);
}
```
Porch camera: existing 384x288 SubViewport TextureRect, remove REC, muted grey-green CRT, 85% desaturation, 8% scanline, 15% edge darkening. Ordinary TEXTURE shader:
```glsl
shader_type canvas_item;
void fragment(){
 vec3 c=texture(TEXTURE,UV).rgb;
 float l=dot(c,vec3(.299,.587,.114));
 c=mix(c,vec3(l)*vec3(.92,1.,.94),.85);
 c*=1.0-.08*step(.5,fract(UV.y*144.));
 c*=1.0-.15*smoothstep(.25,.7,length(UV-.5));
 COLOR=vec4(c,1.);
}
```
## 4. Customer filtering and economy
Current robber chance 55% daily from day 2; masked or drifter, obvious descriptions. Replace certainty from clothing with observable behavior, one question, ledger of verified history and rumors. No outfit definitive. Global reputation starts 50; fair +3, lowball -4, unjustified refusal -2, counterfeit offered as genuine -8, once per encounter. Known robber refusal no penalty. Proposed drifter risk tiers 65/40/15/5/0 based on trust/employment; masked robber independent. Do not punish player for unknowable information. Ledger tabs customers, antiques, accounts; discovered info only.
## 5. Ranked jam fixes
1. Physical differences across all 40 variants (8 kinds x5). Use existing base Meshy models with attached variant geometry/materials/textures. One genuine and four copies per kind; visible diagnostic features, not merely UI text. Review Items.make and COPIES. Remove anachronisms: 2019 bear, Harlan died 1961 if setting 1956, barcode, battery watch etc. Maintain coherent provenance. Random wear is not proof of counterfeit.
2. Inspection tutorial, clue positions that are physically reachable, readable zoom/rotation, return to inspection from haggle without losing encounter state. Items.estimate must not leak hidden clue count. Existing tip/flip and found clue list should remain. Teach using a safe first item. 
3. Persistent dialogue and seven-day story. Implement visit history and event-gated arcs above. Keep story optional, avoid long forced conversations.
4. Shop visual polish using layout, lighting, six props maximum, porch camera and web-friendly effects. Keep walk paths clear.
5. Balance economy and complete endings. Audit _buy stock-full behavior (no money loss or item disappearance); _arrived randomness; _buyer_arrived hidden value selection and automatic fake rejection. Let player select inventory to present; distinguish disclosed reproductions from fraud. Seed sellers.shuffle and all randomness for reproducible tests. Guaranteed genuine item does not guarantee profitable item or matching buyer. Ensure fair buyer availability and final-day clearance opportunity. Separate cash movement from realized profit. Endings: A Place in Town (rent paid and strong community), Open for Business (rent paid), The Last Customer (rent unpaid). Verify day 7 can be won without knowing hidden values.
## Implementation and acceptance
Work in a separate implementation branch; no unrelated rewrites. Prioritize playable core and authenticity before polish. Inspect current source and report differences. Test all variants, clue reachability, haggle, full inventory, buyer choice, door refusal, save migration, day transitions and all endings. Run multiple seeded seven-day simulations including cautious and average players. Export single-threaded Godot web build, test browser performance and controls, check console errors. Provide commit hashes, test evidence, remaining risks and asset requests. Do not claim playtesting without running it.
## Review limitations
This handoff reconstructs the earlier review from available context; exact original dialogue dictionaries, shader wording and illustrative mockups were not retrievable. All major recommendations are represented, but this is not a verbatim copy. Original review was source-based, not a live playtest. Coordinates, shaders, balance and dialogue are proposals, not validated implementation. 1956, reputation values and schedule are design suggestions. No gameplay changes are made by this document.
