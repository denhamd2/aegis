class_name Roster
extends RefCounted
## The selectable roster, and the single place that knows which model scene,
## colourway and card copy belong to a wrestler.
##
## It is a data table rather than a folder of .tres files because every field
## here is consumed by exactly two callers -- the title screen's select cards
## and the match it launches -- and a table is the form a test can walk end to
## end. Adding a wrestler is one entry plus his model scene; nothing in
## TitleScreen names a wrestler.
##
## Two entries today, because two character models exist: the repo ships
## roman_reigns.glb and cody_rhodes.glb and nothing else that is rigged to the
## game's wrestler rig. wrestler_base.glb is the CC0 retargeting mannequin, not
## a character, so it is deliberately not offered here.

## One roster slot.
##
## `model_scene` is a path, not a preload: the character scenes pull in the
## heavy .glb (roman_reigns.glb alone is 52MB), and preloading both of them
## from a script the title screen parses would make the menu pay for the whole
## roster before a player has picked anybody. They are loaded at launch, once,
## for the two men actually walking to the ring.
class Entry:
	var id: String
	var first_name: String
	var last_name: String
	var tagline: String
	var model_scene: String
	## Drives the ring gear on models that use the universal attire builder,
	## and -- for every model -- the wrestler's HUD plate flash and his card
	## on the select screen. Chosen so the two cards separate by hue at a
	## glance, the same relationship VISUAL_BAR.md measures between the two
	## men in the ring.
	var attire_body: Color
	var attire_accent: Color
	## Card copy only. These are presentation values for the select screen's
	## bars -- the match does not read them, and no combat number is derived
	## from them. They are here so the cards say something about a wrestler
	## rather than sitting empty.
	var power: float
	var speed: float
	var technique: float

	func _init(p_id: String, p_first: String, p_last: String, p_tagline: String,
			p_scene: String, p_body: Color, p_accent: Color,
			p_power: float, p_speed: float, p_technique: float) -> void:
		id = p_id
		first_name = p_first
		last_name = p_last
		tagline = p_tagline
		model_scene = p_scene
		attire_body = p_body
		attire_accent = p_accent
		power = p_power
		speed = p_speed
		technique = p_technique

	func display_name() -> String:
		return "%s %s" % [first_name, last_name]

	func initials() -> String:
		return "%s%s" % [first_name.substr(0, 1), last_name.substr(0, 1)]


static func entries() -> Array:
	return [
		Entry.new(
			"roman", "ROMAN", "REIGNS", "THE HEAD OF THE TABLE",
			"res://scenes/roman_model.tscn",
			Color(0.07, 0.08, 0.11), Color(0.55, 0.63, 0.76),
			0.92, 0.58, 0.74),
		Entry.new(
			"cody", "CODY", "RHODES", "THE AMERICAN NIGHTMARE",
			"res://scenes/cody_model.tscn",
			Color(0.88, 0.86, 0.82), Color(0.86, 0.68, 0.26),
			0.74, 0.80, 0.86),
	]


static func by_id(id: String) -> Entry:
	for entry: Entry in entries():
		if entry.id == id:
			return entry
	return null
