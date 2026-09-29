extends Node
func _ready() -> void:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	scene.match_seed = 1
	add_child(scene)
	var ws: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	for w in ws: w.is_ai = true
	var t := 0
	var last := ["", ""]
	while t < 9000:
		await get_tree().physics_frame
		t += 1
		for i in 2:
			var w := ws[i]
			var st: String = WrestlerFSM.State.keys()[w.fsm.current_state]
			if st != last[i] and st in ["DOWN", "TIE_UP", "GRAPPLE_HOLD", "PIN_ATTACKER", "FINISHER"]:
				print("t%d %s %s" % [t, w.name, st])
			last[i] = st
		if t % 500 == 0:
			for w in ws:
				print("  t%d %s st=%s pos=(%.2f,%.2f) dmg=%.0f since=%.0f mom=%.0f tier=%d trapped=%s lock=%d limbs=%s" % [t, w.name,
					WrestlerFSM.State.keys()[w.fsm.current_state], w.global_position.x, w.global_position.z,
					w.combat.total_damage(), w.combat.total_damage() - w._damage_at_last_knockdown,
					w.combat.momentum, w.combat.tier_reached, w.is_corner_trapped(), w._corner_lockout, w.combat.limb_damage.values()])
	get_tree().quit()
