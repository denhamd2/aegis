extends GdUnitTestSuite
## The live ropes (core/ring/ring_ropes.gd) and the whip's rope load
## (WrestlerController.rope_load_offset), against gauntlet/refs/ropes.md.

const DT := 1.0 / 60.0

func _ropes() -> RingRopes:
	var r: RingRopes = auto_free(RingRopes.new())
	r.setup(RingBuilder.ROPE_SPAN, RingBuilder.ROPE_END,
			RingBuilder.ROPE_HEIGHTS, RingBuilder.ROPE_SAG, RingBuilder.ROPE_RADIUS,
			StandardMaterial3D.new())
	return r

## The +Z top rope, and a body pressed into it mid-span.
func _top_north(r: RingRopes) -> RingRopes.Rope:
	for rope in r._ropes:
		if rope.side == 0 and is_equal_approx(rope.height, RingBuilder.ROPE_HEIGHT_TOP):
			return rope
	return null

## A torso-sized sphere coming out from inside the ring at `speed` until its
## back is `depth` past the rope line, then held there.
func _press_in(r: RingRopes, rope: RingRopes.Rope, depth: float, ticks: int,
		speed := 6.0) -> void:
	var radius := 0.15
	var start := RingBuilder.ROPE_SPAN - radius - 0.3
	var stop := RingBuilder.ROPE_SPAN + depth - radius - RingBuilder.ROPE_RADIUS
	for i in ticks:
		var z := minf(start + speed * DT * i, stop)
		# A torso, as RingRopes samples one: a column of spheres up the
		# spine. (One sphere alone, the rope just slides round it.)
		var torso := []
		for k in 9:
			torso.append(Vector4(0.0, 0.9 + 0.07 * k, z, radius))
		r._spheres = [torso, [], [], []]
		r._step(rope, DT)

func _run(r: RingRopes, rope: RingRopes.Rope, ticks: int) -> void:
	for i in ticks:
		r._step(rope, DT)

func test_twelve_ropes_at_rest_on_their_parabolas() -> void:
	var r := _ropes()
	assert_int(r.rope_count()).is_equal(12)
	var rope := _top_north(r)
	# Ends at the turnbuckles, sag at mid-span, exactly as ring.py sweeps it.
	assert_float(rope.rest[0].x).is_equal_approx(-RingBuilder.ROPE_END, 0.001)
	var mid := rope.rest[RingRopes.SEGMENTS / 2]
	assert_float(mid.y).is_equal_approx(
			RingBuilder.ROPE_HEIGHT_TOP - RingBuilder.ROPE_SAG_TOP, 0.0005)
	assert_float(mid.z).is_equal_approx(RingBuilder.ROPE_SPAN, 0.0001)
	assert_float(r.max_deflection()).is_equal(0.0)

## A back 0.4 m past the rope line takes it 0.4 m out at the contact, less
## toward the posts (a V, as the footage shows), and the ends never move.
func test_a_body_in_the_ropes_bends_them_into_a_v() -> void:
	var r := _ropes()
	var rope := _top_north(r)
	_press_in(r, rope, 0.4, 40)
	var mid := rope.d[RingRopes.SEGMENTS / 2]
	assert_float(mid.x).is_greater(0.36)
	var quarter := rope.d[RingRopes.SEGMENTS / 4]
	assert_float(quarter.x).is_greater(0.05)
	assert_float(quarter.x).is_less(mid.x * 0.75)
	assert_vector(rope.d[0]).is_equal(Vector2.ZERO)
	assert_vector(rope.d[RingRopes.SEGMENTS]).is_equal(Vector2.ZERO)

## Let go, it springs back through its line, swings a few times and settles
## -- two or three visible swings, not a buzz and not a slow drift.
func test_released_it_rings_down_and_settles() -> void:
	var r := _ropes()
	var rope := _top_north(r)
	_press_in(r, rope, 0.4, 40)
	r._spheres = [[], [], [], []]
	var crossings := 0
	var last := rope.d[RingRopes.SEGMENTS / 2].x
	var peak_after := 0.0
	for i in 60:
		r._step(rope, DT)
		var now := rope.d[RingRopes.SEGMENTS / 2].x
		if signf(now) != signf(last) and absf(now) > 0.002:
			crossings += 1
		last = now
		if i > 30:
			peak_after = maxf(peak_after, absf(now))
	# ~7 Hz over the first second: swings through, not a slow creep back.
	assert_int(crossings).is_greater_equal(4)
	# And rung down to a small fraction by half a second on.
	assert_float(peak_after).is_less(0.08)
	_run(r, rope, 240)
	assert_bool(r._settled(rope)).is_true()

## However hard it is pushed, a rope stops at MAX_DEFLECTION.
func test_deflection_is_capped() -> void:
	var r := _ropes()
	var rope := _top_north(r)
	_press_in(r, rope, 1.6, 60)
	assert_float(r.max_deflection()).is_less_equal(RingRopes.MAX_DEFLECTION + 0.001)

## A foot pressing down on a rope pushes it DOWN, not out.
func test_a_boot_on_the_rope_presses_it_down() -> void:
	var r := _ropes()
	var rope := _top_north(r)
	var top := RingBuilder.ROPE_HEIGHT_TOP - RingBuilder.ROPE_SAG_TOP
	# The boot comes down onto it from above and settles 0.12 m in.
	for i in 20:
		var y := lerpf(top + 0.15, top + 0.055 + 0.018 - 0.12, minf(i / 12.0, 1.0))
		r._spheres = [[Vector4(0.0, y, RingBuilder.ROPE_SPAN, 0.055)], [], [], []]
		r._step(rope, DT)
	var mid := rope.d[RingRopes.SEGMENTS / 2]
	assert_float(mid.y).is_less(-0.10)
	assert_float(absf(mid.x)).is_less(0.01)

## The whip's rope load: free travel to the real ropes, a half-sine into
## them peaking ROPE_LOAD_DEPTH further on, then thrown back; ~0.25 s in all
## at the launch speed, the contact time refs/ropes.md derives.
func test_rope_load_carries_him_into_the_ropes_and_back() -> void:
	var v := WrestlerController.IRISH_WHIP_LAUNCH_SPEED
	var peak := 0.0
	var t := 0.0
	while WrestlerController.rope_load_offset(t, v) >= 0.0 and t < 2.0:
		peak = maxf(peak, WrestlerController.rope_load_offset(t, v))
		t += 0.001
	assert_float(peak).is_equal_approx(
			WrestlerController.ROPE_LOAD_FREE + WrestlerController.ROPE_LOAD_DEPTH, 0.01)
	assert_float(t).is_between(0.15, 0.30)
	# Continuous where the free travel meets the ropes.
	var t_free := WrestlerController.ROPE_LOAD_FREE / v
	assert_float(WrestlerController.rope_load_offset(t_free - 0.0005, v)).is_equal_approx(
			WrestlerController.rope_load_offset(t_free + 0.0005, v), 0.01)


## A hand holding the top rope (RingRopes.hold; EntranceDirector's step
## through the ropes): the rope comes up to the hand as a soft peak, never
## past HOLD_MAX, and let down gradually it settles back without the
## twang the owner saw -- nothing on the rope moves faster on screen than a
## hand does.
func test_a_held_rope_lifts_softly_and_is_let_down_without_a_twang() -> void:
	var r := _ropes()
	var rope := _top_north(r)
	var at := Vector3(0.4, RingBuilder.ROPE_HEIGHT_TOP + 0.5, RingBuilder.ROPE_SPAN)
	var hold := {"side": 0, "height": RingBuilder.ROPE_HEIGHT_TOP, "at": at,
			"weight": 1.0, "grip": true}
	r._holds["hand"] = hold
	_run(r, rope, 30)
	var i_at := roundi((0.4 + RingBuilder.ROPE_END) / (2.0 * RingBuilder.ROPE_END)
			* RingRopes.SEGMENTS)
	assert_float(rope.d[i_at].y).is_between(0.15, RingRopes.HOLD_MAX + 0.001)
	# A soft peak: half a metre along, still well up; at the post, nothing.
	var i_half := i_at + roundi(0.5 / (2.0 * RingBuilder.ROPE_END) * RingRopes.SEGMENTS)
	assert_float(rope.d[i_half].y).is_between(0.02, rope.d[i_at].y)
	assert_float(rope.d[RingRopes.SEGMENTS].length()).is_equal(0.0)
	# Let down over ten frames, as the director eases a grip out.
	var fastest := 0.0
	for k in 60:
		hold["weight"] = maxf(0.0, 1.0 - float(k) / 10.0)
		var before := rope.d.duplicate()
		r._step(rope, DT)
		for i in rope.d.size():
			fastest = maxf(fastest, (rope.d[i] - (before[i] as Vector2)).length() / DT)
	assert_float(fastest).is_less(4.0)
	r._holds.clear()
	_run(r, rope, 120)
	assert_float(rope.d[i_at].length()).is_less(0.02)
