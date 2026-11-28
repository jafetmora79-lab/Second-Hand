extends RefCounted
class_name Dialogue
## What the townsfolk say, and the week's small stories (the Harlan estate, 1956). Lines move on with what has actually happened:
## Toby only has his sled once you've paid him enough for it; the stranger only finds work once the lodge is reopening and he trusts you;
## Miss Vale only apologises once you've shown her you can spot a copy. Everything here is optional colour: the rent is still the goal.
##
## Each seller has: visits (greetings in order, each gated by `_gate`), final (their last price), door_reject (turned away at the door),
## fake (shown the evidence that it's a copy), friendly / firm / suspicious (answers to the three things you can say), rumor (what they
## let slip about the Harlan estate when they trust you).

const SELLERS := {
	"trapper": {
		"visits": ["Morning. Found this in my late brother's cabin. Thought you might know what it's worth.",
			"Been patching his roof. Funny what turns up under old floorboards.",
			"Cabin's nearly ready for winter. You treated me square last time.",
			"My brother would have liked this shop."],
		"final": "That's as low as I go: %s.", "door_reject": "Right. I'll try again another day.",
		"fake": "Well, I'll be. He must have been fooled too.", "friendly": "You're a decent sort.",
		"firm": "A shop has to make a living, I suppose.", "suspicious": "Found it where I said I did.",
		"rumor": "My brother bought half his things off Harlan, the carver. Said the old man's estate went cheap, and fast."},
	"collector": {
		"visits": ["I have something rather unusual. I trust you know your antiques.",
			"I've been looking into the Harlan estate. Some of those pieces are rather questionable.",
			"Someone in this valley is passing reproductions off as originals. I mean to find out who.",
			"I owe you an apology. Your eye is better than I expected."],
		"final": "I won't entertain anything under %s.", "door_reject": "I shall remember that.",
		"fake": "Let me see that mark. Good heavens.", "friendly": "Courtesy is becoming rare.",
		"firm": "Very well. Business is business.", "suspicious": "Are you questioning my judgment?",
		"rumor": "Compare the estate marks carefully. The real Harlan pieces were sold at auction in '49. Nothing new should be turning up."},
	"widow": {
		"visits": ["My husband kept this for years. I thought someone else might enjoy it.",
			"I've been sorting his things. The house feels rather empty.",
			"It's easier, knowing his things won't simply be thrown away.",
			"Thank you for giving his belongings a new home, dear."],
		"final": "I think %s is the least I can take.", "door_reject": "Oh. I'm sorry to have bothered you.",
		"fake": "He always thought it was real.", "friendly": "That's very kind of you.",
		"firm": "I understand.", "suspicious": "It was his. That's all I know.",
		"rumor": "My husband knew Harlan, before the estate sale. He said the old man's nephew sold everything off in a week."},
	"kid": {
		"visits": ["Hey! How much would you give me for this? I'm saving for a sled.",
			"I'm nearly halfway to the sled!",
			"Found another thing in the attic. Mom said I could sell it.",
			"I got my sled! You should see how fast it goes."],
		"final": "%s is my lowest. Promise.", "door_reject": "Oh. Okay.",
		"fake": "Wait... it's not real?", "friendly": "You're the best!",
		"firm": "Fine, fine.", "suspicious": "I didn't steal it! Honest!",
		"rumor": "I saw a man carrying boxes out of the old Harlan place. At night!"},
	"drifter": {
		"visits": ["Got anything for this? Just need enough to get through the night.",
			"Still stuck here. Roads aren't getting any better.",
			"Heard the lodge might have some work going.",
			"Got a job at the lodge. Thought I'd stop by and thank you."],
		"final": "%s. That's all I can take.", "door_reject": "Yeah. Figures.",
		"fake": "Didn't know. Bought it off someone else.", "friendly": "Not many people talk to me like that.",
		"firm": "All right.", "suspicious": "Why all the questions?",
		"rumor": "Fellow at the station offered me a box of 'estate pieces' for next to nothing. Didn't smell right."},
}

const BUYERS := {
	"collector_b": {
		"visits": ["Mr. Pell. I'm cataloguing the collections of this valley: instruments and timepieces.",
			"Have you come across any Harlan pieces? Real ones, I mean.",
			"Your stock has filled several gaps in my catalogue.",
			"The catalogue is nearly complete. You've been a great help."],
		"empty": "Nothing for my catalogue today, I'm afraid."},
	"decorator": {
		"visits": ["Jo, from the lodge. We're reopening for the season and I need pieces with a bit of character.",
			"The lobby is coming together. Got anything for the bedrooms?",
			"Guests keep asking about our antiques. I send them your way.",
			"The lodge opens on Saturday. Come up sometime: half of it came from your shelves."],
		"empty": "Nothing quite right for the lodge today."},
}

## At the door, asked what they want. A robber's answer gives him away to a careful ear (no outfit settles it on its own).
const DOOR := {
	"robber": "\"Open up. I've got something to sell.\" He doesn't say what.",
	"robbing_drifter": "\"Can we talk inside?\" He doesn't take his hands out of his pockets.",
	"collector_b": "\"Pell. I'm buying, not selling.\"",
	"decorator": "\"Jo, from the lodge! Let me in, it's freezing.\"",
}

## The three things you can say to a seller, once each visit.
const CHOICES := [
	["friendly", "\"Let's find a price we're both happy with.\""],
	["firm", "\"I have to leave room for a profit.\""],
	["ask", "\"Tell me where this really came from.\""],
]

## Which of a seller's or buyer's greetings fits now: the next in order, but only as far as what has happened allows.
static func greeting(id: String, rec: Dictionary, town: Dictionary) -> String:
	var lines: Array = (SELLERS[id] if SELLERS.has(id) else BUYERS[id])["visits"]
	var n := int(rec.get("visits", 1)) - 1                       ## 0 on the first visit
	var i := clampi(n, 0, lines.size() - 1)
	i = mini(i, _gate(id, rec, town))
	return lines[i]

## The furthest greeting the story has earned for `id`.
static func _gate(id: String, rec: Dictionary, town: Dictionary) -> int:
	match id:
		"trapper":                                              ## "you treated me square" needs a fair deal with him
			return 3 if int(rec.get("fair_deals", 0)) >= 2 else (2 if int(rec.get("fair_deals", 0)) >= 1 else 1)
		"collector":                                            ## her suspicion grows as fakes come to light; the apology needs your eye
			if int(town.get("fakes_exposed", 0)) >= 2 and int(rec.get("fake_exposed", 0)) >= 1:
				return 3
			return 2 if int(town.get("fakes_exposed", 0)) >= 1 else 1
		"kid":                                                  ## the sled costs $90
			var paid := int(rec.get("paid_total", 0))
			if paid >= 90:
				return 3
			return 1 if paid >= 30 else 0
		"drifter":                                              ## work at the lodge: Jo has to be reopening, and he has to trust you
			if int(town.get("jo_sales", 0)) >= 2 and int(rec.get("trust", 50)) >= 60:
				return 3
			return 2 if int(rec.get("fair_deals", 0)) >= 1 else 1
		"collector_b":
			return 3 if int(town.get("pell_sales", 0)) >= 3 else (2 if int(town.get("pell_sales", 0)) >= 1 else 1)
		"decorator":
			return 3 if int(town.get("jo_sales", 0)) >= 3 else (2 if int(town.get("jo_sales", 0)) >= 1 else 1)
	return 9

## A word for how much someone trusts you (0..100).
static func trust_word(t: int) -> String:
	if t >= 75:
		return "trusts you"
	if t >= 60:
		return "friendly"
	if t >= 45:
		return "wary"
	if t >= 30:
		return "cold"
	return "hostile"
