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
## Three entries today, because three character models exist: the repo ships
## roman_reigns.glb, cody_rhodes.glb and kenny_omega.glb, and nothing else that
## is rigged to the game's wrestler rig. wrestler_base.glb is the CC0
## retargeting mannequin, not a character, so it is deliberately not offered
## here.
##
## Kenny is appended rather than inserted, and that ordering is load-bearing in
## two places: DEFAULT_PAIR below resolves by id and is unaffected, but the
## title screen's cursor starts at 0 and steps to 1 after player 1 picks, so
## the default two Enters are still Roman then Cody. tools/probe/title_video.gd
## drives exactly those two Enters. Inserting Kenny anywhere earlier would
## silently change who the recorded video and every unseeded probe fight.

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
	## This wrestler's own finisher, as a MoveDef path, or "" for none --
	## the one move on the roster that belongs to one man rather than to the
	## match scene everybody shares. Installed on WrestlerController.
	## finisher_move by TitleScreen.configure_match().
	var finisher: String
	## His own signature, as a MoveDef path, or "" for none. Added to the
	## signature draw beside the shared ones rather than replacing them, so
	## a wrestler with one gains a move and loses nothing.
	var signature: String
	## The title he holds, as the entrance lower third prints it -- "AEW
	## CHAMPION" -- or "" for a man who holds none. See entrance_subtitle().
	var championship: String = ""
	## His own moveset, where he has one: tier -> MoveDef paths, the first of
	## each the tier's guaranteed move and the rest its pool. A tier named
	## here REPLACES the shared one match.tscn gives everybody -- a man's
	## moveset is his, not a draw from the other men's -- and a tier left out
	## keeps the shared moves. Keys: "strike", "grapple", "power",
	## "signature" (drawn beside `signature`, which still goes first),
	## "running". Installed by TitleScreen.configure_match().
	var moveset: Dictionary = {}
	## His real billed height, in metres, and his model's own height to the
	## top of the head (hair excluded) at scale 1.0, measured off the model
	## scene. configure_match() scales him by the ratio, so the men stand at
	## their true heights relative to each other -- the owner: "Roman looks
	## too small compared to Cody". Before this the slot decided a man's size
	## (match.tscn: WrestlerA 0.98, WrestlerB 1.05), which put Cody 7 cm taller
	## than Roman, who is billed an inch taller than him.
	var stature_m := 0.0
	var model_height_m := 0.0

	## The physique_height that stands him at his real height, or 0 if unknown.
	func stature_scale() -> float:
		return stature_m / model_height_m if stature_m > 0.0 and model_height_m > 0.0 else 0.0

	func _init(p_id: String, p_first: String, p_last: String, p_tagline: String,
			p_scene: String, p_body: Color, p_accent: Color,
			p_power: float, p_speed: float, p_technique: float,
			p_finisher: String = "", p_signature: String = "") -> void:
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
		finisher = p_finisher
		signature = p_signature

	func display_name() -> String:
		return "%s %s" % [first_name, last_name]

	## The small line above his name on the entrance lower third: his title if
	## he is a champion, otherwise his nickname -- the owner's rule for the
	## graphic, off the AEW reference it copies.
	func entrance_subtitle() -> String:
		return championship if championship != "" else tagline

	func initials() -> String:
		return "%s%s" % [first_name.substr(0, 1), last_name.substr(0, 1)]


static func entries() -> Array:
	var list := [
		Entry.new(
			"roman", "ROMAN", "REIGNS", "THE HEAD OF THE TABLE",
			"res://scenes/roman_model.tscn",
			Color(0.07, 0.08, 0.11), Color(0.55, 0.63, 0.76),
			0.92, 0.58, 0.74,
			# The Spear, and the Superman Punch he sets it up with.
			"res://resources/moves/finisher_spear.tres",
			"res://resources/moves/signature_superman_punch.tres"),
		Entry.new(
			"cody", "CODY", "RHODES", "THE AMERICAN NIGHTMARE",
			"res://scenes/cody_model.tscn",
			Color(0.88, 0.86, 0.82), Color(0.86, 0.68, 0.26),
			0.74, 0.80, 0.86,
			# Cross Rhodes, and the Cody Cutter.
			"res://resources/moves/finisher_cross_rhodes.tres",
			"res://resources/moves/signature_cody_cutter.tres"),
		# The body colour is his scanned vest and tights, sampled from
		# kenny_omega_tex_u1_v1_diffuse: the gear reads as a dark desaturated
		# navy-charcoal, around Color(0.12, 0.15, 0.20).
		#
		# The accent is NOT sampled, and that is deliberate. The same sample
		# puts his trim at h=0.10, which is Cody's gold, and his tights within
		# a hair of Roman's Color(0.07, 0.08, 0.11) body -- so taking the
		# measured colours would give three cards that do not separate, which
		# is the one job this pair of fields has on the select screen. Teal is
		# chosen instead: adjacent to the blue he actually wears rather than
		# arbitrary, well clear of Cody's gold, and separated from Roman's
		# desaturated steel blue by being both green-shifted and saturated.
		#
		# He does not use the universal attire builder (KennyModel returns
		# false), so unlike Roman and Cody these two colours drive only his
		# card and his HUD plate -- never cloth on the model.
		Entry.new(
			"kenny", "KENNY", "OMEGA", "THE BEST BOUT MACHINE",
			"res://scenes/kenny_model.tscn",
			Color(0.12, 0.15, 0.20), Color(0.20, 0.78, 0.72),
			0.68, 0.88, 0.94),
	]
	# Roman holds the title: the owner's reference for the entrance graphic
	# is his, captioned AEW CHAMPION. The others walk out under their
	# nicknames.
	(list[0] as Entry).championship = "AEW CHAMPION"
	# Billed heights (WWE / AEW profiles): Roman 6'3", Cody 6'2", Kenny 6'0".
	# Model heights are each model's crown at scale 1.0, hair excluded: Cody's
	# and Kenny's Body mesh top (1.837; Kenny_Body 1.737, the AAA rebuild). Roman's is CALIBRATED, not his
	# head_skinned top (1.895), which overstates his skull -- that mesh
	# carries the base of his hair -- and stood him eye to eye with Cody when
	# he should look down on him an inch. Calibrated by eye height in the
	# face-off stance (tools/probe/stature_shot.tscn, 5 cm lines): posed eyes
	# 1.721 m for Roman and 1.695 m for Cody at scale 1.0; Roman's model
	# height is Cody's scaled by that ratio, 1.837 * 1.721 / 1.695 = 1.866.
	for pair: Array in [[0, 1.905, 1.866], [1, 1.880, 1.837], [2, 1.829, 1.737]]:
		(list[pair[0]] as Entry).stature_m = pair[1]
		(list[pair[0]] as Entry).model_height_m = pair[2]
	# Roman's own moveset, in place of the shared draw of 26 running attacks
	# that handed him Claymores and Hoedowns (the Tribal Chief does not hit a
	# Claymore): clubbing strikes and a heavy kick, a clinch knee and a vertical
	# suplex, the bodyslam and powerslam of a big man, the Superman Punch to set
	# up the Spear, and a few lariats and knees on the run.
	const M := "res://resources/moves/"
	(list[0] as Entry).moveset = {
		"strike": [M + "strike_jab.tres", M + "strike_cross.tres",
				M + "strike_kick_heavy.tres"],
		"grapple": [M + "grapple_clinch_knee.tres", M + "grapple_vertical_suplex.tres",
				M + "grapple_guillotine.tres"],
		"power": [M + "power_samoan_drop.tres", M + "power_bodyslam.tres",
				M + "power_powerslam.tres"],
		"signature": [M + "signature_superman_punch.tres", M + "signature_backbreaker.tres"],
		"running": [M + "running_attack_clothesline.tres",
				M + "running_clothesline_from_hell.tres", M + "running_knee_lift.tres",
				M + "running_drive_by.tres"],
	}
	# Cody's own moveset (gauntlet/refs/cody_moveset.md): the moves he hits in
	# nearly every match, in place of the shared draw.
	(list[1] as Entry).moveset = {
		"strike": [M + "strike_jab.tres", M + "strike_bionic_elbow.tres",
				M + "strike_dropdown_uppercut.tres", M + "strike_cross.tres"],
		"grapple": [M + "grapple_vertical_suplex.tres"],
		"power": [M + "power_powerslam.tres", M + "power_alabama_slam.tres"],
		"signature": [M + "signature_disaster_kick.tres", M + "signature_pedigree.tres"],
		"running": [M + "running_attack_clothesline.tres",
				M + "running_single_leg_dropkick.tres"],
		"submission": [M + "submission_figure_four.tres"],
		"dive": [M + "dive_tope_suicida.tres", M + "dive_springboard_disaster_kick.tres"],
	}
	return list


static func by_id(id: String) -> Entry:
	for entry: Entry in entries():
		if entry.id == id:
			return entry
	return null


## --- Probe defaults ---------------------------------------------------------

## The two men an AI-vs-AI probe fights unless it is told otherwise.
##
## Roman against Cody rather than either mirror match: a mirror hides
## everything that depends on which model sits in which slot, and these probes
## exist to measure the live match rather than a symmetrical fixture. The
## measurements themselves are unaffected either way -- combat resolves from
## MoveDefs and the seed, never from the mesh -- so this is about what the
## probe frames and its output name, not about the numbers.
const DEFAULT_PAIR := ["roman", "cody"]


## Resolves a `--wrestlers roman,cody` spec to two entries; an empty spec
## gives DEFAULT_PAIR.
##
## Returns an empty array on anything it cannot resolve rather than
## substituting a default, and pushes the reason: a probe that quietly fought
## somebody other than who it was asked to fight has measured nothing, and
## every caller here prints the pair it got before it runs.
static func pair_from_spec(spec: String = "") -> Array:
	var ids: Array = DEFAULT_PAIR
	if not spec.strip_edges().is_empty():
		ids = []
		for token: String in spec.split(","):
			ids.append(token.strip_edges())
	if ids.size() != 2:
		push_error("--wrestlers wants exactly two ids, got %d: %s"
				% [ids.size(), ", ".join(ids)])
		return []
	var pair: Array = []
	for id: String in ids:
		var entry := by_id(id)
		if entry == null:
			push_error("no roster entry '%s'; roster is: %s"
					% [id, ", ".join(ids_on_roster())])
			return []
		pair.append(entry)
	return pair


static func ids_on_roster() -> Array:
	var ids: Array = []
	for entry: Entry in entries():
		ids.append(entry.id)
	return ids
