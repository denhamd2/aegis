extends GdUnitTestSuite
## Blood (the owner's blood round): the weapons that open a man up do, the
## size of the shot and what he has left decide how much, it runs rather than
## pops, the switch turns it all off, and the canvas keeps one stain map
## however much a match bleeds.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")
const BLOOD_BAKER := preload("res://tools/blood/bake_blood_masks.gd")
const MODELS := ["res://scenes/roman_model.tscn", "res://scenes/cody_model.tscn",
		"res://scenes/kenny_model.tscn"]


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	w.character_model_scene = load("res://scenes/kenny_model.tscn")
	add_child(w)
	await _ticks(2)
	return w


func _blood(w: WrestlerController) -> Blood:
	return w.get_node_or_null("Blood") as Blood


func test_face_blood_stays_in_narrow_streaks_as_it_builds() -> void:
	var frame := {"up": Vector3.UP, "fwd": Vector3.FORWARD, "right": Vector3.RIGHT,
			"wound": Vector3.ZERO, "chest": Vector3(0, -0.3, 0)}
	var streak := BLOOD_BAKER.head_field(Vector3(0, -0.12, 0), frame)
	var skin_between_streaks := BLOOD_BAKER.head_field(Vector3(0.02, -0.12, 0), frame)
	assert_float(streak).is_less(0.4)
	assert_float(skin_between_streaks).is_greater(streak * 2.0)
	assert_float(skin_between_streaks).is_equal(1.0)


func _swing(id: StringName) -> MoveDef:
	return WeaponCatalog.swing_move(WeaponCatalog.by_id(id))


func test_every_skin_surface_has_its_reveal_map() -> void:
	Blood.enabled = true
	for path: String in MODELS:
		var model: Node3D = auto_free((load(path) as PackedScene).instantiate())
		add_child(model)
		await _ticks(1)
		var skin: Array = model.get_meta("skin_materials", [])
		var w: WrestlerController = auto_free(WrestlerController.new())
		var b := Blood.attach(w, model)
		assert_object(b).is_not_null()
		var surfaces := 0
		for node in model.find_children("", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				if skin.has(mi.get_surface_override_material(s)):
					surfaces += 1
					assert_object(mi.get_surface_override_material(s).next_pass).is_not_null()
		assert_int(b.materials.size()).override_failure_message(path).is_equal(surfaces)
		assert_int(surfaces).is_greater(0)


func test_the_dangerous_weapons_open_him_up_and_the_soft_ones_do_not() -> void:
	Blood.enabled = true
	var w := await _wrestler()
	var b := _blood(w)
	assert_object(b).is_not_null()
	b._on_damaged(_swing(&"inflatable_banana"))
	b._on_damaged(_swing(&"kendo_stick"))
	b._on_damaged(WeaponCatalog.swing_move(WeaponCatalog.by_id(&"fire_extinguisher")))
	assert_float(b.head).is_equal(0.0)
	# a plain move never opens a cut either
	var punch := MoveDef.new()
	punch.damage_head = 8.0
	b._on_damaged(punch)
	assert_float(b.head).is_equal(0.0)
	b._on_damaged(_swing(&"steel_chair"))
	var chair := b.head
	assert_float(chair).is_between(0.04, 0.12)
	# open, the kendo stick and the punch make it run harder
	b._on_damaged(_swing(&"kendo_stick"))
	assert_float(b.head).is_greater(chair)
	var kendo := b.head
	b._on_damaged(punch)
	assert_float(b.head).is_greater(kendo)


func test_barbed_wire_cuts_deeper_than_a_chair() -> void:
	Blood.enabled = true
	var a := _blood(await _wrestler())
	var c := _blood(await _wrestler())
	a._on_damaged(_swing(&"steel_chair"))
	c._on_damaged(_swing(&"barbed_wire_bat"))
	assert_float(c.head).is_greater(a.head * 1.5)


func test_a_beaten_man_bleeds_more_from_the_same_shot() -> void:
	Blood.enabled = true
	var fresh := _blood(await _wrestler())
	var worn_w := await _wrestler()
	var worn := _blood(worn_w)
	var beating := MoveDef.new()
	beating.damage_torso = 60.0
	beating.damage_legs = 40.0
	worn_w.combat.apply_damage(beating)
	assert_float(worn_w.combat.health()).is_less(0.6)
	fresh._on_damaged(_swing(&"steel_chair"))
	worn._on_damaged(_swing(&"steel_chair"))
	assert_float(worn.head).is_greater(fresh.head * 1.2)


func test_landing_on_the_tacks_opens_his_back() -> void:
	Blood.enabled = true
	var b := _blood(await _wrestler())
	b._on_damaged(WeaponCatalog.landing_move(WeaponCatalog.by_id(&"thumbtacks")))
	assert_float(b.back).is_greater(0.17)
	assert_float(b.head).is_equal(0.0)


func test_it_runs_rather_than_pops_and_keeps_running() -> void:
	Blood.enabled = true
	var w := await _wrestler()
	var b := _blood(w)
	b._on_damaged(_swing(&"barbed_wire_bat"))
	var opened := b.head
	await _ticks(3)
	# three frames in, the skin shows only the start of it
	assert_float(b.shown_head).is_less(opened * 0.5)
	await _ticks(240)
	assert_float(b.shown_head).is_greater(opened * 0.8)
	# and the cut has crept past where it was opened
	assert_float(b.head).is_greater(opened)
	assert_float(b.head).is_less_equal(opened + Blood.CREEP_ABOVE + 0.001)


func test_blood_off_bleeds_nothing() -> void:
	Blood.enabled = false
	var w := await _wrestler()
	assert_object(_blood(w)).is_null()
	Blood.enabled = true


func test_the_canvas_keeps_one_stain_map_however_much_is_spilt() -> void:
	var mesh: MeshInstance3D = auto_free(MeshInstance3D.new())
	var mat := StandardMaterial3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.set_surface_override_material(0, mat)
	add_child(mesh)
	var c := CanvasBlood.attach(mesh)
	assert_float(c.coverage()).is_equal(0.0)
	assert_object(mat.next_pass).is_null()        # nothing until the first drop
	assert_bool(c.stamp(Vector3(9, 0, 0), 0.1, 0.5)).is_false()   # off the mat
	assert_bool(c.stamp(Vector3(0.5, 0, -0.4), 0.2, 0.6)).is_true()
	assert_object(mat.next_pass).is_not_null()
	var after_pool := c.coverage()
	assert_float(after_pool).is_greater(0.0)
	for i in 200:
		c.drip(Vector3(-1.0 + i * 0.01, 0, 0.3))
	c.spatter(Vector3(0, 0, 0), Vector3.RIGHT, 1.2)
	c.smear(Vector3(1, 0, 1), Vector3(2, 0, 1.4), 0.08)
	c.flush()
	assert_float(c.coverage()).is_greater(after_pool)
	assert_int(mesh.get_child_count()).is_equal(1)
	# the same spot over and over saturates, it does not grow
	var px := c.texel(Vector3(0.5, 0, -0.4))
	for i in 20:
		c.stamp(Vector3(0.5, 0, -0.4), 0.2, 0.6)
	assert_float(c.image.get_pixelv(px).r).is_less_equal(1.0)


func test_match_ring_canvas_has_a_live_blood_overlay() -> void:
	var ring: Node3D = auto_free(load("res://scenes/ring.tscn").instantiate())
	add_child(ring)
	await _ticks(2)
	var floor_mesh := ring.get_node("Floor/MeshInstance3D") as MeshInstance3D
	var canvas := floor_mesh.get_node_or_null("CanvasBlood") as CanvasBlood
	assert_object(canvas).is_not_null()
	assert_bool(canvas.mesh == floor_mesh).is_true()
	assert_bool(canvas.stamp(Vector3.ZERO, 0.08, 0.8)).is_true()
	canvas.flush()
	assert_object(canvas.material).is_not_null()
	assert_object(canvas.texture).is_not_null()
	assert_bool(canvas.canvas_material.next_pass == canvas.material).is_true()
