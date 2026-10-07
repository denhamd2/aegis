class_name Sweat
extends Node
## Drives a wrestler's sweat over the match (SkinLook.set_wetness;
## gauntlet/refs/aaa_gap.md, item 5).
##
## Wetness comes from two things a broadcast shows: time worked, and punishment
## taken. A man is a little damp from his entrance (BASE), wet by the end of a
## long match (FULL_SECONDS of the clock running), and wetter still for every
## big move he has eaten.
##
## PRESENTATION ONLY. It reads the clock and CombatSystem.total_damage() and
## writes nothing but material parameters, so the simulation, the replay and
## its hash cannot see it. The clock only runs while the wrestler's physics
## does -- not through the entrance, not through a frozen capture.

## 0.08 -> 0.22 and the full-wet clock 150 -> 100 s in the 2K26 lighting
## round (lighting_2k26.md item 5): its wrestlers glisten under the rig from
## the bell, not only by the end.
## Back down to 0.1 against the owner's 2K26 match (cody_roman_2k26.md):
## a soft sheen from the bell, not a gloss.
const BASE := 0.1
## Seconds of match for the time share to reach its full TIME_SHARE.
##
## 100 -> 475. The old number is in the line it replaced: "AI matches here run
## 30 s to 2.5 min, so a long one ends soaked". They do not any more. The match
## flow was taken to 2K26's in the same round as this change and a match now
## runs 474 s (428-518), measured by flow_probe against the reference's 475
## (gauntlet/refs/match_engine_2k26.md). Against that, a 100 s clock was full a
## FIFTH of the way in: from 1:40 on, both men sat at BASE + TIME_SHARE = 0.65
## before damage, and soaked for the remaining six minutes. The owner, playing
## it: "the wrestlers are sweating way too much during the match".
##
## So it is the match's own length, which is what the constant always meant --
## "a long one ends soaked" is right, it was the length of a long one that
## moved. A man is damp at the bell and soaked at the finish, and the climb
## between them is the match.
const FULL_SECONDS := 475.0
## 0.6 -> 0.55 with BASE raised, so time alone still stops short of soaked.
const TIME_SHARE := 0.55
## Total limb damage that adds the full DAMAGE_SHARE.
##
## 160 -> 300, for the same reason and in the same proportion: the ceiling is
## 400 (four limbs at CombatSystem.MAX_LIMB_DAMAGE 100), and over eight minutes
## of 2K26 flow a man passes 160 early enough that the damage term, too, was
## pinned for most of the match. 300 keeps a beating worth something at the
## finish without being spent by the first near-fall.
##
## BodyLife.DAMAGE_FULL is this number (test_hit_flinch_and_life pins them
## equal): the breathing and the slump run off the same scale and were stale
## for the same reason.
const DAMAGE_FULL := 300.0
const DAMAGE_SHARE := 0.35
## Materials change slowly; four updates a second is plenty.
const UPDATE_EVERY := 0.25

var wrestler: WrestlerController
var materials: Array[BaseMaterial3D] = []
var _clock := 0.0
var _since := UPDATE_EVERY
var wetness := -1.0


## Hangs a Sweat on `w` for the skin materials its model registered as meta
## "skin_materials" (the models set it where they build those materials).
static func attach(w: WrestlerController, model: Node) -> Sweat:
	var sweat := Sweat.new()
	sweat.name = "Sweat"
	sweat.wrestler = w
	if model and model.has_meta("skin_materials"):
		for m in model.get_meta("skin_materials"):
			if m is BaseMaterial3D:
				sweat.materials.append(m)
	w.add_child(sweat)
	return sweat


func _process(delta: float) -> void:
	if wrestler == null or materials.is_empty():
		return
	if wrestler.is_physics_processing():
		_clock += delta
	_since += delta
	if _since < UPDATE_EVERY:
		return
	_since = 0.0
	var damage := wrestler.combat.total_damage() if wrestler.combat else 0.0
	var w := target(_clock, damage)
	if absf(w - wetness) < 0.005:
		return
	wetness = w
	for m in materials:
		SkinLook.set_wetness(m, w)


static func target(seconds: float, damage: float) -> float:
	return clampf(BASE + TIME_SHARE * clampf(seconds / FULL_SECONDS, 0.0, 1.0)
			+ DAMAGE_SHARE * clampf(damage / DAMAGE_FULL, 0.0, 1.0), 0.0, 1.0)
