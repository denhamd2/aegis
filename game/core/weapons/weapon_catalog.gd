class_name WeaponCatalog
extends RefCounted
## Every No Holds Barred weapon (gauntlet/refs/weapons_nhb.md), in wheel
## order, and the MoveDef each kind of swing uses. The models are the
## tools/blender/weapons/ builds in assets/weapons/; the belt is Roman's
## title (assets/props/aew_title.glb), held by its Held* nodes.
##
## Damage is per hit before the swing's scale: a jab is 7 to the head, a big
## boot about 12, so a chair shot at 10 sits with the heavy strikes and the
## gun and the launcher are finishing blows.

const DIR := "res://assets/weapons/"
const BELT_GLB := "res://assets/props/aew_title.glb"

## How each swing is timed and where it lands, relative to the swinger
## (forward -Z), in the MoveDef fields every strike uses. The clip each plays
## is `weapon_<swing>` in StrikeRecipes.
## [startup, active, recovery, contact offset, contact radius, damage scale]
const SWINGS := {
	WeaponDef.Swing.OVERHEAD: [18, 4, 26, Vector3(0.0, 1.62, -0.85), 0.26, 1.0],
	WeaponDef.Swing.SIDE: [16, 4, 24, Vector3(0.05, 1.45, -0.95), 0.26, 1.0],
	WeaponDef.Swing.THRUST: [12, 4, 20, Vector3(0.0, 1.15, -1.0), 0.22, 0.8],
	WeaponDef.Swing.WHIP: [14, 4, 22, Vector3(0.0, 1.45, -1.1), 0.30, 1.0],
	WeaponDef.Swing.PUNCH: [12, 4, 24, Vector3(-0.079, 1.48, -0.72), 0.13, 1.0],
	WeaponDef.Swing.CHOP: [12, 4, 22, Vector3(0.10, 1.55, -0.78), 0.22, 1.0],
	WeaponDef.Swing.GUN: [30, 2, 40, Vector3(0.0, 1.35, -1.0), 0.20, 1.0],
	WeaponDef.Swing.LAUNCHER: [50, 2, 60, Vector3(0.0, 1.40, -1.0), 0.20, 1.0],
	WeaponDef.Swing.SPRAY: [20, 40, 20, Vector3(0.0, 1.55, -0.9), 0.35, 1.0],
	WeaponDef.Swing.POUR: [30, 10, 30, Vector3(0.0, 0.0, -0.8), 0.40, 0.0],
}
const SWING_NAMES := {
	WeaponDef.Swing.OVERHEAD: "overhead", WeaponDef.Swing.SIDE: "side",
	WeaponDef.Swing.THRUST: "thrust", WeaponDef.Swing.WHIP: "whip",
	WeaponDef.Swing.PUNCH: "punch", WeaponDef.Swing.CHOP: "chop",
	WeaponDef.Swing.GUN: "gun", WeaponDef.Swing.LAUNCHER: "launcher",
	WeaponDef.Swing.SPRAY: "spray", WeaponDef.Swing.POUR: "pour",
}
## Weapon-specific performances may share gameplay timing while using their
## own body clip and hand-relative prop path.
const SWING_PROFILES := {
	"baseball_bat": "bat", "barbed_wire_bat": "bat", "lead_pipe": "bat", "sledgehammer": "bat",
}
## Ranged: they hit whoever is in front of him out to this far, not at the
## contact sphere (WrestlerController resolves them).
const RANGED := {WeaponDef.Swing.GUN: 9.0, WeaponDef.Swing.LAUNCHER: 14.0, WeaponDef.Swing.SPRAY: 2.4}

## id, name, family, glb, held, dented, broken, set_up, swing, head, torso,
## hits to dent, hits to break, two-handed, set piece, landing damage, sound,
## owners, effects
const TABLE := [
	["steel_chair", "Steel Chair", WeaponDef.Family.CHAIRS, "steel_chair", "SteelChair_Folded",
		"SteelChair_Bent", "", "SteelChair_Open", WeaponDef.Swing.OVERHEAD, 10.0, 3.0, 4, 0, true, false, 0.0,
		"hit_metal", ["roman", "kenny"], {}],
	["barbed_wire_chair", "Barbed Wire Chair", WeaponDef.Family.CHAIRS, "barbed_wire_chair",
		"BarbedWireChair_Folded", "", "", "BarbedWireChair_Open", WeaponDef.Swing.OVERHEAD, 13.0, 4.0, 0, 0,
		true, false, 0.0, "hit_metal", [], {}],
	["baseball_bat", "Baseball Bat", WeaponDef.Family.SWUNG, "baseball_bat", "BaseballBat_Clean", "", "", "",
		WeaponDef.Swing.SIDE, 9.0, 3.0, 0, 0, true, false, 0.0, "hit_wood", [], {}],
	["barbed_wire_bat", "Barbed Wire Bat", WeaponDef.Family.SWUNG, "barbed_wire_bat", "BarbedWireBat_Clean",
		"", "", "", WeaponDef.Swing.SIDE, 12.0, 3.0, 0, 0, true, false, 0.0, "hit_wood", [], {}],
	["kendo_stick", "Kendo Stick", WeaponDef.Family.SWUNG, "kendo_stick", "KendoStick_Clean", "",
		"KendoStick_Broken", "", WeaponDef.Swing.SIDE, 8.0, 3.0, 0, 8, true, false, 0.0, "hit_wood", [], {}],
	["sledgehammer", "Sledgehammer", WeaponDef.Family.SWUNG, "sledgehammer", "Sledgehammer_Clean", "", "", "",
		WeaponDef.Swing.OVERHEAD, 14.0, 4.0, 0, 0, true, false, 0.0, "hit_metal", [], {}],
	["lead_pipe", "Lead Pipe", WeaponDef.Family.SWUNG, "lead_pipe", "LeadPipe_Clean", "", "", "",
		WeaponDef.Swing.SIDE, 10.0, 3.0, 0, 0, false, false, 0.0, "hit_metal", [], {}],
	["board_with_nails", "2x4 With Nails", WeaponDef.Family.SWUNG, "board_with_nails", "BoardWithNails_Clean",
		"", "BoardWithNails_Broken", "", WeaponDef.Swing.SIDE, 12.0, 3.0, 0, 4, true, false, 0.0, "hit_wood", [], {}],
	["shovel", "Shovel", WeaponDef.Family.SWUNG, "shovel", "Shovel_Clean", "", "", "", WeaponDef.Swing.SIDE,
		10.0, 3.0, 0, 0, true, false, 0.0, "hit_metal", [], {}],
	["hockey_stick", "Hockey Stick", WeaponDef.Family.SWUNG, "hockey_stick", "HockeyStick_Clean", "", "", "",
		WeaponDef.Swing.SIDE, 8.0, 3.0, 0, 0, true, false, 0.0, "hit_wood", [], {}],
	["crutch", "Crutch", WeaponDef.Family.SWUNG, "crutch", "Crutch_Clean", "", "", "", WeaponDef.Swing.SIDE,
		8.0, 2.0, 0, 0, true, false, 0.0, "hit_metal", [], {}],
	["stop_sign", "Stop Sign", WeaponDef.Family.SWUNG, "stop_sign", "StopSign_Clean", "StopSign_Dented", "",
		"", WeaponDef.Swing.OVERHEAD, 9.0, 3.0, 3, 0, true, false, 0.0, "hit_metal", [], {}],
	["guitar", "Guitar", WeaponDef.Family.SWUNG, "guitar", "Guitar_Clean", "", "Guitar_Broken", "",
		WeaponDef.Swing.OVERHEAD, 13.0, 2.0, 0, 1, true, false, 0.0, "hit_wood", [], {}],
	["inflatable_banana", "Inflatable Banana", WeaponDef.Family.SWUNG, "inflatable_banana",
		"InflatableBanana_Clean", "", "InflatableBanana_Broken", "", WeaponDef.Swing.SIDE, 1.0, 0.5, 0, 3,
		true, false, 0.0, "whoosh", [], {}],
	["trash_can", "Trash Can", WeaponDef.Family.CARRIED, "trash_can", "TrashCan_Clean", "TrashCan_Dented", "",
		"", WeaponDef.Swing.OVERHEAD, 9.0, 3.0, 3, 0, true, false, 0.0, "hit_metal", [], {}],
	["steel_steps", "Steel Steps", WeaponDef.Family.CARRIED, "steel_steps", "SteelSteps_Top", "", "",
		"SteelSteps_Clean", WeaponDef.Swing.OVERHEAD, 15.0, 6.0, 0, 0, true, false, 0.0, "hit_metal",
		["roman"], {}],
	["ring_bell", "Ring Bell", WeaponDef.Family.CARRIED, "ring_bell", "RingBell_Clean", "", "", "",
		WeaponDef.Swing.CHOP, 9.0, 2.0, 0, 0, false, false, 0.0, "bell_ding", [], {}],
	["championship_belt", "Championship Belt", WeaponDef.Family.CARRIED, "", "", "", "", "",
		WeaponDef.Swing.OVERHEAD, 9.0, 2.0, 0, 0, true, false, 0.0, "hit_metal", ["roman"], {}],
	["cookie_sheet", "Cookie Sheet", WeaponDef.Family.CARRIED, "cookie_sheet", "CookieSheet_Clean",
		"CookieSheet_Dented", "", "", WeaponDef.Swing.OVERHEAD, 6.0, 1.0, 2, 0, false, false, 0.0, "hit_metal",
		[], {}],
	["frying_pan", "Frying Pan", WeaponDef.Family.CARRIED, "frying_pan", "FryingPan_Clean", "", "", "",
		WeaponDef.Swing.CHOP, 9.0, 2.0, 0, 0, false, false, 0.0, "hit_metal", [], {}],
	["briefcase", "Briefcase", WeaponDef.Family.CARRIED, "briefcase", "Briefcase_Clean", "", "", "",
		WeaponDef.Swing.OVERHEAD, 8.0, 3.0, 0, 0, true, false, 0.0, "hit_kick", [], {}],
	["table", "Table", WeaponDef.Family.SET_PIECES, "table", "Table_Folded", "", "Table_Broken", "Table_Up",
		WeaponDef.Swing.OVERHEAD, 10.0, 4.0, 0, 0, true, true, 14.0, "hit_wood", ["roman", "kenny"], {}],
	["ladder", "Ladder", WeaponDef.Family.SET_PIECES, "ladder", "Ladder_Closed", "", "", "Ladder_Open",
		WeaponDef.Swing.THRUST, 11.0, 5.0, 0, 0, true, false, 0.0, "hit_metal", [], {}],
	["thumbtacks", "Thumbtacks", WeaponDef.Family.SET_PIECES, "thumbtacks", "Thumbtacks_Bag", "", "",
		"Thumbtacks_Scattered", WeaponDef.Swing.POUR, 0.0, 0.0, 0, 0, false, true, 12.0, "hit_kick", [], {}],
	["bed_of_nails", "Bed of Nails", WeaponDef.Family.SET_PIECES, "bed_of_nails", "BedOfNails_Clean", "", "",
		"BedOfNails_Clean", WeaponDef.Swing.POUR, 0.0, 0.0, 0, 0, true, true, 14.0, "hit_wood", [], {}],
	["light_tubes", "Light Tubes", WeaponDef.Family.SET_PIECES, "light_tubes", "LightTubes_Clean", "",
		"LightTubes_Broken", "", WeaponDef.Swing.SIDE, 11.0, 3.0, 0, 1, true, false, 0.0, "hit_glass", [], {}],
	["barbed_wire_board", "Barbed Wire Board", WeaponDef.Family.SET_PIECES, "barbed_wire_board",
		"BarbedWireBoard_Clean", "", "", "BarbedWireBoard_Clean", WeaponDef.Swing.OVERHEAD, 11.0, 5.0, 0, 0,
		true, true, 14.0, "hit_wood", [], {}],
	["fire_extinguisher", "Fire Extinguisher", WeaponDef.Family.SPRAYS, "fire_extinguisher",
		"FireExtinguisher_Clean", "", "", "", WeaponDef.Swing.SPRAY, 2.0, 0.0, 0, 0, true, false, 0.0,
		"whoosh", [], {"cloud": "FireExtinguisher_Cloud"}],
	["handgun", "Handgun", WeaponDef.Family.SPRAYS, "handgun", "Handgun_Clean", "", "", "",
		WeaponDef.Swing.GUN, 22.0, 8.0, 0, 0, false, false, 0.0, "pyro_bang", [],
		{"flash": "Handgun_Flash"}],
	["rpg", "Rocket Launcher", WeaponDef.Family.SPRAYS, "rpg", "Rpg_Clean", "", "", "",
		WeaponDef.Swing.LAUNCHER, 30.0, 14.0, 0, 0, true, false, 0.0, "pyro_boom", [],
		{"rocket": "Rpg_Rocket", "blast": "Rpg_Blast"}],
	["chain", "Chain", WeaponDef.Family.WHIPS, "chain", "Chain_Clean", "", "", "", WeaponDef.Swing.WHIP, 9.0,
		3.0, 0, 0, false, false, 0.0, "hit_metal", [], {}],
	["weight_belt", "Weight Belt", WeaponDef.Family.WHIPS, "weight_belt", "WeightBelt_Clean", "", "", "",
		WeaponDef.Swing.WHIP, 8.0, 3.0, 0, 0, false, false, 0.0, "hit_punch", ["cody"], {}],
	["brass_knuckles", "Brass Knuckles", WeaponDef.Family.WHIPS, "brass_knuckles", "BrassKnuckles_Clean", "",
		"", "", WeaponDef.Swing.PUNCH, 12.0, 2.0, 0, 0, false, false, 0.0, "hit_punch", [], {}],
]

## How each weapon is carried when he is not swinging it: which of its points
## (a marker) sits where in his own frame (+X his right, +Y up, -Z ahead),
## and which way it faces -- a direction in the weapon's own axes that
## points along a direction in his. WeaponGrip puts the weapon there and his
## hands onto it. Presets by how the weapon is built:
##   SHOULDER  long things built along +Y from the grip (a bat): over the
##             right shoulder, leaning back
##   HANG      built hanging down from the grip (a folded chair, a chain, a
##             can by its handles): in front, at the chest or at the side
## [anchor marker, anchor at, local_up -> world_up, local_fwd -> world_fwd]
const _SHOULDER := ["grip_r", Vector3(0.20, 1.12, -0.22),
		Vector3(0, 1, 0), Vector3(-0.12, 0.72, 0.68), Vector3(0, 0, -1), Vector3(0.0, 0.68, -0.72)]
## A chair by its two front legs, hanging upside down in front of him, the
## seat facing him: picked up the way it is swung.
const _CHAIR_BY_THE_LEGS := ["grip_r", Vector3(0.20, 1.08, -0.36),
		Vector3(0, -1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]
const _HANG_FRONT := ["grip_r", Vector3(0.10, 1.25, -0.40),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)]
const _HANG_SIDE := ["grip_r", Vector3(0.27, 0.98, -0.12),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)]
const CARRY := {
	"steel_chair": _CHAIR_BY_THE_LEGS, "barbed_wire_chair": _CHAIR_BY_THE_LEGS,
	"baseball_bat": _SHOULDER, "barbed_wire_bat": _SHOULDER, "kendo_stick": _SHOULDER,
	"sledgehammer": _SHOULDER, "lead_pipe": _SHOULDER, "board_with_nails": _SHOULDER,
	"shovel": _SHOULDER, "hockey_stick": _SHOULDER, "crutch": _SHOULDER, "stop_sign": _SHOULDER,
	"inflatable_banana": _SHOULDER, "light_tubes": _SHOULDER, "cookie_sheet": _SHOULDER,
	# the guitar's grip is on the neck with the body below it (-Y)
	"guitar": ["grip_r", Vector3(0.20, 1.12, -0.22),
		Vector3(0, -1, 0), Vector3(-0.12, 0.72, 0.68), Vector3(0, 0, -1), Vector3(0.0, 0.68, -0.72)],
	"trash_can": ["grip_r", Vector3(0.26, 1.12, -0.32),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)],
	# square in front of him, a hand on each side, the handled edge against
	# his stomach: how ring steps are carried (two men's work; he manages)
	"steel_steps": ["grips", Vector3(0.0, 1.0, -0.28),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)],
	"ring_bell": ["grip_r", Vector3(0.20, 1.00, -0.32),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)],
	# by the end of its strap at his side, the plate hanging, face out
	"championship_belt": ["grip_r", Vector3(0.27, 0.98, -0.10),
		Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)],
	# by the handle at his side, the pan hanging -- not held up at his chest
	"frying_pan": ["grip_r", Vector3(0.27, 0.96, -0.08),
		Vector3(0, 1, 0), Vector3(0.1, -1, 0.15), Vector3(0, 0, -1), Vector3(-1, 0, 0)],
	"briefcase": ["grip_r", Vector3(0.30, 0.86, -0.04),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
	# folded flat: carried upright in front by its top edge, a hand at each
	# end of it, top facing out
	"table": ["grips", Vector3(0.0, 1.18, -0.36),
		Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
	# closed: under his arm, top end ahead
	"ladder": ["grip_r", Vector3(0.50, 1.12, -0.05),
		Vector3(0, 1, 0), Vector3(0, 0.15, -0.99), Vector3(0, 0, -1), Vector3(1, 0, 0)],
	"thumbtacks": _HANG_SIDE,
	"bed_of_nails": ["grip_r", Vector3(0.55, 1.10, -0.38),
		Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
	"barbed_wire_board": ["grip_r", Vector3(0.40, 1.30, -0.42),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)],
	"fire_extinguisher": _HANG_SIDE,
	# low ready: the barrel ahead and down
	"handgun": ["grip_r", Vector3(0.22, 1.05, -0.32),
		Vector3(0, 1, 0), Vector3(0, 0.87, -0.5), Vector3(0, 0, -1), Vector3(0, -0.5, -0.87)],
	# on the right shoulder, aimed ahead
	"rpg": ["shoulder", Vector3(0.17, 1.47, 0.02),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0.03, -1)],
	"chain": _HANG_SIDE, "weight_belt": _HANG_SIDE,
	# on the fist: no carry, it goes where the hand goes
	"brass_knuckles": [],
}

## Two-handed to swing, one-handed to carry, as a person does it: a case by
## its handle, an extinguisher by its grip, a closed ladder under one arm, a
## belt by its strap. The left hand joins for the swing (WeaponGrip), and
## hangs free till then.
const ONE_HAND_CARRY: Array[StringName] = [&"briefcase", &"fire_extinguisher", &"ladder",
		&"championship_belt"]

## Wide things swung in both hands, a hand at each side: their swing paths
## steer the point between the hands, not the right hand's grip. Steered by the
## right hand, the left handle of an 84 cm set of steps ended up past the
## left arm's reach at the top of the swing (test_weapon_grip_contact).
const CENTRED_SWING: Array[StringName] = [&"steel_steps", &"table", &"briefcase", &"trash_can",
		&"barbed_wire_board", &"ladder", &"fire_extinguisher"]

## How it comes up off the floor (WrestlerController's pickup actions): the
## squat lift for the heavy ones, both hands for the long and the two-handed,
## one hand for the rest.
const HEAVY_LIFT: Array[StringName] = [&"steel_steps", &"table", &"trash_can", &"ladder",
		&"bed_of_nails", &"barbed_wire_board", &"light_tubes", &"rpg", &"fire_extinguisher"]


static func pickup_action(def: WeaponDef) -> String:
	if def.id in HEAVY_LIFT:
		return "pickup_heavy"
	if def.two_handed and not def.id in ONE_HAND_CARRY:
		return "pickup_two"
	return "pickup"


static var _defs: Array[WeaponDef] = []
static var _moves := {}


## All of them, in wheel order (families in Family order, then as listed).
static func all() -> Array[WeaponDef]:
	if _defs.is_empty():
		for row: Array in TABLE:
			_defs.append(_make(row))
		_defs.sort_custom(func(a: WeaponDef, b: WeaponDef) -> bool:
			return a.family < b.family if a.family != b.family else _table_order(a) < _table_order(b))
	return _defs


static func _table_order(d: WeaponDef) -> int:
	for i in TABLE.size():
		if StringName(TABLE[i][0]) == d.id:
			return i
	return 0


static func by_id(id: StringName) -> WeaponDef:
	for d in all():
		if d.id == id:
			return d
	return null


static func in_family(family: int) -> Array[WeaponDef]:
	var out: Array[WeaponDef] = []
	for d in all():
		if d.family == family:
			out.append(d)
	return out


static func _make(row: Array) -> WeaponDef:
	var d := WeaponDef.new()
	d.id = StringName(row[0])
	d.display_name = row[1]
	d.family = row[2]
	d.glb = (DIR + String(row[3]) + ".glb") if String(row[3]) != "" else BELT_GLB
	d.held = row[4]
	d.dented = row[5]
	d.broken = row[6]
	d.set_up = row[7]
	d.swing = row[8]
	d.damage_head = row[9]
	d.damage_torso = row[10]
	d.hits_to_dent = row[11]
	d.hits_to_break = row[12]
	d.two_handed = row[13]
	d.set_piece = row[14]
	d.landing_damage = row[15]
	d.sound = row[16]
	for o: String in row[17]:
		d.owners.append(StringName(o))
	d.effects = row[18]
	d.throwable = d.swing != WeaponDef.Swing.POUR or d.id == &"thumbtacks"
	return d


## The MoveDef a swing of `weapon` plays: the swing's timing and reach with
## the weapon's damage. One per weapon, made once.
static func swing_move(weapon: WeaponDef) -> MoveDef:
	if _moves.has(weapon.id):
		return _moves[weapon.id]
	var s: Array = SWINGS[weapon.swing]
	var m := MoveDef.new()
	m.animation_pair_id = StringName("weapon_" + swing_profile(weapon))
	m.startup_frames = s[0]
	m.active_frames = s[1]
	m.recovery_frames = s[2]
	m.reversal_window_start = maxi(0, int(s[0]) - 6)
	m.reversal_window_end = int(s[0]) - 1
	m.contact_offset = s[3]
	m.contact_radius = s[4]
	m.damage_head = weapon.damage_head * float(s[5])
	m.damage_torso = weapon.damage_torso * float(s[5])
	m.momentum_gain = 6.0 + weapon.damage_head * 0.5
	m.leaves_defender_down = weapon.swing in [WeaponDef.Swing.GUN, WeaponDef.Swing.LAUNCHER] \
			or weapon.damage_head >= 12.0
	m.resource_name = "weapon_" + String(weapon.id)
	m.set_meta(&"weapon", weapon.id)
	_moves[weapon.id] = m
	return m


## The hit a thrown `weapon` lands: most of a swing's damage, no reach (the
## flight decides where it lands), a knockdown for the heavy ones.
static func throw_move(weapon: WeaponDef) -> MoveDef:
	var key := StringName(String(weapon.id) + "_thrown")
	if _moves.has(key):
		return _moves[key]
	var m := MoveDef.new()
	m.startup_frames = 1
	m.active_frames = 1
	m.recovery_frames = 1
	m.damage_head = weapon.damage_head * 0.7
	m.damage_torso = weapon.damage_torso * 0.7
	m.momentum_gain = 4.0 + weapon.damage_head * 0.4
	m.leaves_defender_down = weapon.damage_head >= 13.0
	m.resource_name = "weapon_thrown_" + String(weapon.id)
	m.set_meta(&"weapon", weapon.id)
	_moves[key] = m
	return m


## The weapon a move was made from (swing_move, throw_move, landing_move),
## or null for a move that is not a weapon's.
static func of_move(move: MoveDef) -> WeaponDef:
	if move == null or not move.has_meta(&"weapon"):
		return null
	return by_id(move.get_meta(&"weapon"))


## A chair lying on the floor is not a set piece, but landing on one hurts.
const CHAIR_LANDING_DAMAGE := 6.0


## The damage of a man landing on `weapon` set up (a table, the tacks...) or
## lying on the floor (a chair): mostly his back.
static func landing_move(weapon: WeaponDef) -> MoveDef:
	var key := StringName(String(weapon.id) + "_landed_on")
	if _moves.has(key):
		return _moves[key]
	var total := weapon.landing_damage if weapon.landing_damage > 0.0 else CHAIR_LANDING_DAMAGE
	var m := MoveDef.new()
	m.startup_frames = 1
	m.active_frames = 1
	m.recovery_frames = 1
	m.damage_head = total * 0.2
	m.damage_torso = total * 0.8
	m.resource_name = "weapon_landed_on_" + String(weapon.id)
	m.set_meta(&"weapon", weapon.id)
	_moves[key] = m
	return m


## The weapon's carry transform for a man at `body` (his global transform),
## given where the anchor marker sits in the weapon (`anchor_local`). Empty
## spec (worn on the hand): Transform3D() and false.
static func carry_transform(weapon: WeaponDef, body: Transform3D, anchor_local: Transform3D) -> Array:
	var spec: Array = CARRY.get(String(weapon.id), [])
	if spec.is_empty():
		return [Transform3D(), false]
	var local := _frame(spec[2], spec[4])
	var world := _frame(spec[3], spec[5])
	var basis := body.basis.orthonormalized() * world * local.inverse()
	var anchor_world: Vector3 = body * (spec[1] as Vector3)
	var origin := anchor_world - basis * anchor_local.origin
	return [Transform3D(basis, origin), true]


## An orthonormal frame from an up and a roughly-forward direction.
static func _frame(up: Vector3, fwd: Vector3) -> Basis:
	var y := up.normalized()
	var z := -(fwd - y * fwd.dot(y)).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


## The weapon's own path through each kind of swing, which the body clip
## (wrestling_clips.py, "No Holds Barred weapons") does not carry: WeaponGrip
## puts the weapon here and the hands onto its grips. Keys are
##   [t, grip, S, U]
## with t over the whole move (contact at startup / total), `grip` where the
## grip_r marker goes, relative to his chest and in his chest's axes (x right,
## y up, -z forward: the chest leans and turns with the clip, so the step and
## the twist carry the weapon), S the way the weapon points (grip to strike)
## and U the way its face leads (orthogonalised against S). Before the first
## key and after the last it eases from and back to the carry.
## A swing with no path (the punch, the launcher on his shoulder, the pour)
## keeps the carry, or the hand, throughout.
const SWING_PATHS := {
	"overhead": [
		[0.22, Vector3(0.10, 0.52, 0.06), Vector3(0.0, 0.45, 0.9), Vector3(0.0, 0.9, -0.45)],
		[0.375, Vector3(0.06, 0.42, -0.40), Vector3(0.0, -0.15, -0.99), Vector3(0.0, -0.99, 0.15)],
		[0.52, Vector3(0.05, -0.02, -0.40), Vector3(0.0, -0.85, -0.5), Vector3(0.0, -0.5, 0.85)],
	],
	"side": [
		[0.20, Vector3(0.30, 0.24, 0.10), Vector3(0.25, 0.65, 0.7), Vector3(-0.95, 0.2, 0.1)],
		[0.364, Vector3(0.04, 0.14, -0.42), Vector3(-0.3, 0.05, -0.95), Vector3(-0.95, 0.0, 0.3)],
		[0.55, Vector3(-0.28, 0.08, -0.22), Vector3(-0.9, 0.15, 0.35), Vector3(0.35, 0.0, 0.9)],
	],
	"bat": [
		[0.20, Vector3(0.30, 0.24, 0.10), Vector3(0.25, 0.65, 0.7), Vector3(-0.95, 0.2, 0.1)],
		[0.375, Vector3(0.04, 0.14, -0.42), Vector3(-0.3, 0.05, -0.95), Vector3(-0.95, 0.0, 0.3)],
		[0.55, Vector3(-0.28, 0.08, -0.22), Vector3(-0.9, 0.15, 0.35), Vector3(0.35, 0.0, 0.9)],
	],
	"thrust": [
		[0.17, Vector3(0.20, -0.14, 0.10), Vector3(-0.1, 0.1, -1.0), Vector3(0.0, 1.0, 0.0)],
		[0.333, Vector3(0.08, -0.06, -0.45), Vector3(-0.1, 0.05, -1.0), Vector3(0.0, 1.0, 0.0)],
		[0.50, Vector3(0.08, -0.08, -0.36), Vector3(-0.1, 0.05, -1.0), Vector3(0.0, 1.0, 0.0)],
	],
	"whip": [
		[0.20, Vector3(0.34, 0.46, 0.14), Vector3(0.2, 0.3, 0.9), Vector3(0.0, 1.0, 0.0)],
		[0.35, Vector3(0.12, 0.26, -0.44), Vector3(-0.1, -0.4, -0.9), Vector3(0.0, -0.9, 0.4)],
		[0.55, Vector3(-0.04, -0.14, -0.34), Vector3(-0.3, -0.9, -0.2), Vector3(0.0, -0.2, 0.9)],
	],
	"chop": [
		[0.20, Vector3(0.28, 0.54, 0.04), Vector3(0.0, 0.6, 0.8), Vector3(0.0, 0.8, -0.6)],
		[0.316, Vector3(0.10, 0.30, -0.44), Vector3(0.0, -0.3, -0.95), Vector3(0.0, -0.95, 0.3)],
		[0.50, Vector3(0.06, -0.04, -0.40), Vector3(0.0, -0.9, -0.4), Vector3(0.0, -0.4, 0.9)],
	],
	"gun": [
		[0.25, Vector3(0.12, 0.14, -0.50), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
		[0.417, Vector3(0.12, 0.14, -0.50), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
		[0.46, Vector3(0.12, 0.19, -0.44), Vector3(0.0, 0.32, -0.95), Vector3(0.0, 0.95, 0.32)],
		[0.66, Vector3(0.12, 0.14, -0.50), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
	],
	# the extinguisher brought up and its horn pointed at him for the spray's
	# 40 ticks (20 to 60 of 80)
	"spray": [
		[0.20, Vector3(0.12, -0.12, -0.34), Vector3(0.0, 0.55, -0.85), Vector3(0.0, 0.85, 0.55)],
		[0.76, Vector3(0.12, -0.12, -0.34), Vector3(0.0, 0.55, -0.85), Vector3(0.0, 0.85, 0.55)],
	],
	# the throw (WrestlerController "throw"): up behind his head, let go at 12/26
	"throw": [
		[0.30, Vector3(0.08, 0.52, 0.08), Vector3(0.0, 0.5, 0.85), Vector3(0.0, 0.85, -0.5)],
		[0.47, Vector3(0.06, 0.46, -0.34), Vector3(0.0, 0.3, -0.95), Vector3(0.0, 0.95, 0.3)],
	],
}


## The path a swing of `weapon` follows (SWING_PATHS), [] if none.
static func swing_path(weapon: WeaponDef) -> Array:
	return SWING_PATHS.get(swing_profile(weapon), [])


static func swing_profile(weapon: WeaponDef) -> String:
	return String(SWING_PROFILES.get(String(weapon.id), SWING_NAMES[weapon.swing]))


## Where `weapon` (shown as `actor`) is at `t` of path `keys`, given his chest
## frame and where the carry (or the hand) would put it.
static func path_transform(actor: WeaponActor, keys: Array, chest: Transform3D, t: float,
		rest: Transform3D) -> Transform3D:
	var axes := swing_axes(actor)
	var grip := actor.marker("grips" if actor.def.id in CENTRED_SWING else "grip_r")
	var first: Array = keys[0]
	var last: Array = keys[keys.size() - 1]
	var key_at := func(k: Array) -> Transform3D:
		var basis := chest.basis.orthonormalized() * _frame_su(k[2], k[3]) * _frame_su(axes[0], axes[1]).inverse()
		return Transform3D(basis, chest * (k[1] as Vector3) - basis * grip.origin)
	if t <= float(first[0]):
		return _blend(rest, key_at.call(first), _ease(t / maxf(float(first[0]), 0.001)))
	if t >= float(last[0]):
		var out := (t - float(last[0])) / maxf(1.0 - float(last[0]), 0.001)
		return _blend(key_at.call(last), rest, _ease(clampf(out * 1.6, 0.0, 1.0)))
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= float(b[0]):
			var u := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return _blend(key_at.call(a), key_at.call(b), _ease(u))
	return rest


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _blend(a: Transform3D, b: Transform3D, w: float) -> Transform3D:
	return Transform3D(a.basis.orthonormalized().slerp(b.basis.orthonormalized(), w), a.origin.lerp(b.origin, w))


## A frame whose -Z is `s` (the way it points) and +Y is `u` made square to it.
static func _frame_su(s: Vector3, u: Vector3) -> Basis:
	var z := -s.normalized()
	var y := (u - z * u.dot(z))
	if y.length() < 0.01:
		y = Vector3.UP - z * z.y if absf(z.y) < 0.95 else Vector3.FORWARD - z * z.z
	y = y.normalized()
	return Basis(y.cross(z).normalized(), y, z)


static var _axes := {}

## The weapon's own [S, U]: S from its grip to what it hits with (the strike
## marker, a gun's muzzle, else along its longest side away from the grip);
## U its flat face -- its thinnest side, signed toward the strike marker's
## offset (the nails of a 2x4, the blade of a hockey stick) -- or, for a gun,
## its top.
static func swing_axes(actor: WeaponActor) -> Array:
	var key := actor.state_root
	if _axes.has(key):
		return _axes[key]
	var box := actor.local_bounds()
	var grip := actor.marker("grip_r").origin
	var s := Vector3.ZERO
	var u := Vector3.ZERO
	var strike := actor.marker("strike")
	var has_strike := actor.has_marker("strike")
	if actor.def.swing == WeaponDef.Swing.SPRAY:
		# the canister, top first: its horn hangs on a hose, so it is the
		# canister he points (the cloud goes where he faces, WeaponActor)
		s = Vector3.UP
		u = Vector3.FORWARD
	elif actor.has_marker("muzzle") and is_ranged(actor.def):
		s = WeaponActor.muzzle_out(actor.marker("muzzle"))
		u = Vector3.UP if absf(s.y) < 0.9 else Vector3.BACK
	else:
		var long := box.get_longest_axis_index()
		var to := (strike.origin if has_strike else box.get_center()) - grip
		s = Vector3.ZERO
		s[long] = 1.0 if to[long] >= 0.0 else -1.0
		if has_strike and to.length() > 0.05:
			s = to.normalized()
		var thin := box.get_shortest_axis_index()
		if thin == long:
			thin = (long + 1) % 3
		u[thin] = 1.0 if not has_strike or (strike.origin - grip)[thin] >= -0.005 else -1.0
	_axes[key] = [s.normalized(), u]
	return _axes[key]


static func carry_anchor(weapon: WeaponDef) -> String:
	var spec: Array = CARRY.get(String(weapon.id), [])
	return spec[0] if not spec.is_empty() else "grip_r"


static func is_ranged(weapon: WeaponDef) -> bool:
	return RANGED.has(weapon.swing)
