class_name Blood
extends Node
## A wrestler bleeding (the owner's blood round: "when the wrestlers are
## attacked by some of the most dangerous weapons I want them to bleed ...
## their damage level should inform the amount of blood").
##
## How it is done, and why:
## - **Weapons open cuts; moves do not.** Broadcast wrestling bleeds from the
##   hardway shots -- a chair, the steps, barbed wire, glass -- and 2K's blood
##   comes from the same place: a weapon's head shot, or damage piled on the
##   head. A strike only makes an open cut run harder. Each weapon has a CUT
##   weight; below OPENS it cannot open a man up at all (a kendo stick, the
##   banana), only worsen one already open.
## - **The hit's size and what he has left set how much.** Each opening shot
##   adds its head damage x CUT x GAIN, and that again for every point of
##   health he had already lost (WORN): a chair at the bell is a cut at the
##   hairline; the same chair late in a war is blood down to the chin.
## - **Once open, it keeps running** (CREEP), a little past the worst it was
##   opened to, as a working man's cut does -- never a fixed decal that
##   stops.
## - **It runs; it never pops.** The level shown eases to the level bled over
##   RUN seconds, and the baked reveal map (tools/blood/bake_blood_masks.gd)
##   turns that level into the order blood reaches the skin: the hairline,
##   rivulets over the brow, the face, the neck, the chest -- the crimson
##   mask. It is painted in each skin surface's UV, so it moves with him.
## - **Fresh, then dry.** Bright and glossy when it has just run, darker and
##   duller as it dries (DRY_SECONDS), fresh again when he is opened up more.
## - **The canvas.** Drips under him while he stands, a pool where he lies,
##   spatter off a shot, a smear where he drags through it (CanvasBlood).
##
## Settings: on by default; off from the title screen's options or
## `--blood off`. Off, nothing bleeds and nothing is painted.
##
## PRESENTATION ONLY. It listens to CombatSystem.damaged and writes material
## parameters and the stain map; the simulation, the replay and its hash
## never see it.

const OVERLAY := preload("res://core/materials/blood_overlay.gdshader")
const MASKS := "res://assets/characters/blood/"

## How readily each weapon opens a man up, per point of head damage it deals.
## Barbed wire, glass and nails cut; heavy steel splits the skin; wood and
## light metal sometimes; foam and fire extinguisher powder never.
const CUT := {
	&"barbed_wire_bat": 1.0, &"barbed_wire_chair": 1.0, &"barbed_wire_board": 1.0,
	&"light_tubes": 1.0, &"board_with_nails": 0.9, &"bed_of_nails": 0.9,
	&"handgun": 0.7, &"steel_steps": 0.7, &"brass_knuckles": 0.6, &"chain": 0.6,
	&"sledgehammer": 0.6, &"steel_chair": 0.6, &"lead_pipe": 0.6, &"ring_bell": 0.55,
	&"shovel": 0.55, &"ladder": 0.5, &"rpg": 0.5, &"guitar": 0.5, &"stop_sign": 0.45,
	&"baseball_bat": 0.45, &"frying_pan": 0.4, &"trash_can": 0.4, &"briefcase": 0.4,
	&"championship_belt": 0.35, &"table": 0.3, &"crutch": 0.3, &"cookie_sheet": 0.3,
	&"weight_belt": 0.25, &"kendo_stick": 0.2, &"hockey_stick": 0.2, &"thumbtacks": 0.5,
	&"fire_extinguisher": 0.0, &"inflatable_banana": 0.0,
}
## How much landing on a set piece opens up his back (the bleed level it
## adds at full health): the tacks, the nails, the wire, the splinters.
const BACK_CUT := {
	&"thumbtacks": 0.30, &"bed_of_nails": 0.42, &"barbed_wire_board": 0.55,
	&"light_tubes": 0.5, &"table": 0.06,
}
## Below this CUT a weapon cannot open a cut, only worsen one.
const OPENS := 0.35
## Bleed level per point of head damage at CUT 1, full health.
const GAIN := 0.01
## The extra share per point of health already lost (health 0.5 -> x1.5).
const WORN := 0.65
## A blow of any kind on an open cut: bleed per point of head damage.
const REOPEN := 0.002
## Bleed added per second while the cut is open, up to CREEP_ABOVE past the
## worst it was opened to.
const CREEP := 0.0012
const CREEP_ABOVE := 0.12
## Seconds for the blood shown to catch up with the blood bled: a run, not a
## pop.
const RUN := 2.5
## Seconds for it to dry from fresh, and the least wet a running cut stays.
const DRY_SECONDS := 150.0
const WET_RUNNING := 0.45
## Canvas: the bleed level a man has to be past before he drips, and the
## fastest and slowest he drips (seconds between drops).
const DRIP_FROM := 0.18
const DRIP_SLOW := 2.4
const DRIP_FAST := 0.35
## Seconds between pool stamps while he lies bleeding.
const POOL_EVERY := 0.7
## His head within this of the mat counts as lying on it.
const LYING := 0.42
const UPDATE_EVERY := 0.05

static var enabled := true
static var _read := false

var wrestler: WrestlerController
var materials: Array[ShaderMaterial] = []
## The level he has bled to (0..1+), the head and the back.
var head := 0.0
var back := 0.0
## What the skin shows (eases toward head/back over RUN).
var shown_head := 0.0
var shown_back := 0.0
var wet := 1.0
var _peak := 0.0
var _since := 0.0
var _drip := 0.0
var _pool := 0.0
var _rng := RandomNumberGenerator.new()


static func on() -> bool:
	if not _read:
		_read = true
		var args := OS.get_cmdline_user_args()
		for i in args.size() - 1:
			if args[i] == "--blood":
				enabled = String(args[i + 1]) != "off"
	return enabled


## Hangs a Blood on `w` for the skin surfaces its model registered as meta
## "skin_materials", each given its baked reveal map. Null with blood off.
static func attach(w: WrestlerController, model: Node) -> Blood:
	if not on() or model == null or not model.has_meta("skin_materials"):
		return null
	var b := Blood.new()
	b.name = "Blood"
	b.wrestler = w
	b._rng.seed = hash(String(model.scene_file_path))
	var skin: Array = model.get_meta("skin_materials")
	var model_name := String(model.scene_file_path).get_file().get_basename()
	for node in model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m == null or not skin.has(m):
				continue
			var path := MASKS + "%s_%s_%d.png" % [model_name, String(mi.name).to_snake_case(), s]
			if not ResourceLoader.exists(path):
				continue
			var overlay := ShaderMaterial.new()
			overlay.shader = OVERLAY
			overlay.set_shader_parameter("reveal", load(path))
			overlay.render_priority = 1
			m.next_pass = overlay
			b.materials.append(overlay)
	if w.combat:
		w.combat.damaged.connect(b._on_damaged)
	w.add_child(b)
	return b


func _on_damaged(move: MoveDef) -> void:
	var weapon := WeaponCatalog.of_move(move)
	var health := wrestler.combat.health() if wrestler.combat else 1.0
	var worn := 1.0 + WORN * (1.0 - health)
	var before := head
	if weapon != null and String(move.resource_name).begins_with("weapon_landed_on_"):
		var cut: float = BACK_CUT.get(weapon.id, 0.0)
		if cut > 0.0:
			back = minf(0.8, back + cut * (0.65 + 0.3 * (1.0 - health)))
			wet = 1.0
		return
	var dealt := move.damage_head
	if dealt <= 0.0:
		return
	if weapon != null:
		var c: float = CUT.get(weapon.id, 0.0)
		if c >= OPENS or head > 0.0:
			head += dealt * c * GAIN * worn
	elif head > 0.0:
		head += dealt * REOPEN * worn
	head = minf(head, 1.3)
	_peak = maxf(_peak, head)
	if head > before:
		wet = 1.0
		_throw_off(head - before)


## Blood off him onto the canvas when a shot lands on an open cut.
func _throw_off(added: float) -> void:
	var canvas := CanvasBlood.of(get_tree())
	if canvas == null:
		return
	var at := bone_at(&"head")
	var ground := Vector3(at.x, 0.0, at.z)
	var dir := Vector3.FORWARD
	if wrestler.opponent:
		dir = at - wrestler.opponent.global_position
	canvas.spatter(ground, dir, clampf(added * 6.0 + shown_head, 0.2, 1.4))


func _process(delta: float) -> void:
	if wrestler == null or materials.is_empty():
		return
	var running := wrestler.is_physics_processing()
	if running:
		if head > 0.0 and head < _peak + CREEP_ABOVE:
			head = minf(head + CREEP * delta, minf(_peak + CREEP_ABOVE, 1.3))
		var k := clampf(delta / RUN, 0.0, 1.0)
		shown_head += (head - shown_head) * k * 3.0 if head > shown_head else 0.0
		shown_back += (back - shown_back) * k * 3.0 if back > shown_back else 0.0
		var floor_wet := WET_RUNNING if head > 0.0 else 0.0
		wet = maxf(floor_wet, wet - delta / DRY_SECONDS)
		_on_canvas(delta)
	_since += delta
	if _since < UPDATE_EVERY:
		return
	_since = 0.0
	for m in materials:
		m.set_shader_parameter("bleed_head", shown_head)
		m.set_shader_parameter("bleed_back", shown_back)
		m.set_shader_parameter("wet", wet)


## Drips while he stands, a pool where he lies.
func _on_canvas(delta: float) -> void:
	if shown_head < DRIP_FROM and shown_back < DRIP_FROM:
		return
	var canvas := CanvasBlood.of(get_tree())
	if canvas == null:
		return
	var h := bone_at(&"head")
	var lying := h.y < LYING
	if lying:
		_pool += delta
		if _pool >= POOL_EVERY:
			_pool = 0.0
			var jitter := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * 0.03
			if shown_head >= DRIP_FROM:
				canvas.stamp(Vector3(h.x, 0, h.z) + jitter, 0.03 + 0.09 * shown_head,
						0.05 + 0.10 * shown_head, 0.45)
			if shown_back >= DRIP_FROM:
				var c := bone_at(&"chest")
				canvas.stamp(Vector3(c.x, 0, c.z) + jitter, 0.04 + 0.10 * shown_back,
						0.04 + 0.08 * shown_back, 0.5)
		return
	_pool = POOL_EVERY * 0.5
	_drip += delta
	var every := lerpf(DRIP_SLOW, DRIP_FAST, clampf((shown_head - DRIP_FROM) / 0.7, 0.0, 1.0))
	if _drip < every * _rng.randf_range(0.7, 1.3):
		return
	_drip = 0.0
	# off the chin, a little ahead of him
	var fwd := -wrestler.global_basis.z
	canvas.drip(Vector3(h.x, 0, h.z) + fwd * 0.08, 0.8 + 0.6 * shown_head)


## The bone names each rig here uses for the head and the chest (the same
## lists the reveal-map bake measures from).
const HEAD_BONES := ["head", "Head", "J_Head", "mixamorig:Head", "CC_Base_Head"]
const CHEST_BONES := ["spine_03", "Spine2", "J_Spine2", "mixamorig:Spine2", "spine.003",
		"CC_Base_Spine02"]
var _bones := {}


## World position of his head (&"head") or chest (&"chest"), on whichever of
## his skeletons carries it -- the models' rigs name them differently.
func bone_at(which: StringName) -> Vector3:
	if not _bones.has(which):
		_bones[which] = _find(wrestler, HEAD_BONES if which == &"head" else CHEST_BONES)
	var found: Array = _bones[which]
	if found.is_empty() or not is_instance_valid(found[0]):
		return wrestler.global_position + Vector3.UP * (1.6 if which == &"head" else 1.3)
	var sk: Skeleton3D = found[0]
	return sk.global_transform * sk.get_bone_global_pose(found[1]).origin


static func _find(root: Node, names: Array) -> Array:
	var skeletons: Array = []
	if root is WrestlerController and (root as WrestlerController).skeleton:
		skeletons.append((root as WrestlerController).skeleton)
	skeletons.append_array(root.find_children("*", "Skeleton3D", true, false))
	for sk: Skeleton3D in skeletons:
		for n: String in names:
			var i := sk.find_bone(n)
			if i >= 0:
				return [sk, i]
	return []
