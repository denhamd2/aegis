extends Node
## Renders the walk to the ring at each of its beats, and measures the walk
## while it happens.
##
## Usage:
##   xvfb-run -a godot4 --path game --resolution 1600x900 \
##       tools/probe/entrance_shots.tscn -- --out /tmp/entrance.png
##
## Two jobs, and the second is the one that matters more.
##
## The SHOTS exist because CLAUDE.md closes every appearance claim on pixels, and
## a still at each beat is minutes of render against the fifty-odd a full video
## costs -- so "is he on the ramp or through it" is a question to answer here and
## not after a two-minute encode.
##
## The MEASUREMENT is the part a screenshot cannot do. Every tick of both walks,
## this records the wrestler's height against `EntranceDirector.surface_y()` and
## his offset from the ramp's centreline, and prints the worst of each at the
## end. A man 4cm under the ramp reads as a man walking down a ramp from every
## camera in the shotlist; the number is the only thing that says otherwise. This
## is the same reasoning tools/probe/floating_probe.gd was written under.

const MATCH_SCENE := "res://scenes/match.tscn"

var _out := "/tmp/entrance.png"
var _shots: Dictionary = {}
## Worst deviation seen, and where. Reported whether or not it is a fault, so
## the run says what it measured rather than only whether it passed.
var _worst_surface := 0.0
var _worst_surface_at := Vector3.ZERO
var _worst_drift := 0.0
var _samples := 0
var _done := false
## Read in the entrances_finished handler; see the comment there.
var _handoff_a := Vector3.ZERO
var _handoff_b := Vector3.ZERO
var _handoff_states := ""



func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]

	var pair := Roster.pair_from_spec("")
	if pair.is_empty():
		get_tree().quit(1)
		return
	print("WRESTLERS ", (pair[0] as Roster.Entry).display_name(), " vs ",
			(pair[1] as Roster.Entry).display_name())

	var scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	# Configured before it enters the tree, which is the ordering
	# configure_match()'s own comment requires -- and the entrances are turned on
	# through the same named call the title screen's launch uses, not by poking
	# the flag, so this probe exercises the real path.
	TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	TitleScreen.configure_entrances(scene, pair[0], pair[1])
	# DEFERRED, and awaited before current_scene is set. The root is still
	# setting up ITS children while this _ready() runs and drops a direct
	# add_child() -- tools/probe/title_video.gd's comment records the same trap,
	# and tools/probe/title_launch.gd shipped with it. Get it wrong and the match
	# never enters the tree: WrestlerController._ready() does not run, so `fsm` is
	# null, `is_inside_tree()` is false, and MatchSetup never starts the walk.
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	# Captured IN the handler, not after the loop. By the time the loop notices,
	# MatchSetup has started the match and both men are moving under their own
	# power -- the first run of this probe reported WrestlerB at z 1.267 in RUN
	# and it read as a handoff fault when it was just the match working.
	director.entrances_finished.connect(func() -> void:
		_done = true
		_handoff_a = a.global_position
		_handoff_b = b.global_position
		_handoff_states = "%s / %s" % [
				WrestlerFSM.State.keys()[a.fsm.current_state],
				WrestlerFSM.State.keys()[b.fsm.current_state]])
	if a.fsm == null or b.fsm == null or not a.is_inside_tree():
		print("ENTRANCE_SHOTS FAILED: the match never entered the tree, so "
				+ "nothing built. See the add_child note above.")
		get_tree().quit(1)
		return

	# MatchSetup._ready() already started the walk; this watches it go past.
	# Beats are recognised from the walk's own state rather than from a clock, so
	# a retimed hold or a changed WALK_SPEED cannot silently slide a shot off the
	# beat it is named after.
	var guard := 0
	while not _done and guard < 60000:
		guard += 1
		await RenderingServer.frame_post_draw
		_measure(a)
		_measure(b)
		# Whose entrance this is comes from the director, not from the FSM. He is
		# in IDLE for every HOLD -- the portal pose and the corner pose included
		# -- so keying the beats off State.ENTRANCE meant the shot named `portal`
		# could only ever be taken while he was still walking out of the tunnel,
		# before the plate had slid on.
		if director.walking_index < 0:
			continue
		var subject: WrestlerController = a if director.walking_index == 0 else b
		var who := "p1" if director.walking_index == 0 else "p2"
		var p := subject.global_position
		# Ordered by Z FIRST, all the way down the ramp, and only then by
		# height. The first version tested height before finishing with Z, and
		# because the ramp is 1.4m above the matting for most of its run, the
		# "on the steps" test fired halfway down the ramp -- so the shot named
		# `4_steps` was a man walking past the floor seats with the ring not
		# even in frame. A beat recognised by the wrong predicate is worse than
		# no beat: it is a screenshot that answers a question nobody asked.
		if p.z <= ArenaBuilder.STAGE_FRONT:
			# Once he has cleared the portal's own face, not on the first frame:
			# at the start of the leg he is still inside the recess with the
			# plate not yet slid on, so the shot named `portal` showed neither.
			if p.z >= EntranceDirector.PORTAL_OUT_Z:
				_maybe_shot("%s_1_portal" % who)
		elif p.z < -14.0:
			_maybe_shot("%s_2_ramp_high" % who)
		elif p.z < EntranceDirector.RAMP_FOOT_Z:
			_maybe_shot("%s_3_ramp_low" % who)
		elif p.y >= EntranceDirector.MAT_Y - 0.02:
			_maybe_shot("%s_6_in_ring" % who)
		elif p.y > EntranceDirector.MAT_SURFACE_Y + 0.15:
			_maybe_shot("%s_5_steps" % who)
		else:
			_maybe_shot("%s_4_ringside" % who)

	_maybe_shot("7_handoff")
	print("ENTRANCE_SHOTS %d saved next to %s" % [_shots.size(), _out])
	for tag: String in _shots.keys():
		print("  ", tag)
	print("SURFACE worst deviation %.4fm at %s over %d samples"
			% [_worst_surface, _worst_surface_at, _samples])
	print("CENTRELINE worst drift on the ramp %.4fm (corridor is +-%.2f)"
			% [_worst_drift, ArenaBuilder.RAMP_HALF_WIDTH])
	print("HANDOFF A %s   B %s   states %s"
			% [_handoff_a, _handoff_b, _handoff_states])
	get_tree().quit(0 if _done else 1)


func _is_walking(w: WrestlerController) -> bool:
	return w.visible and w.fsm.current_state == WrestlerFSM.State.ENTRANCE


## Height against the surface he should be standing on, and drift off the ramp's
## centreline. Only sampled where a surface is defined as a function of Z, which
## is the deck, the ramp and the matting -- not the steps or the canvas, whose
## heights the legs name outright.
func _measure(w: WrestlerController) -> void:
	if not _is_walking(w):
		return
	var p := w.global_position
	if p.z > EntranceDirector.RAMP_FOOT_Z + 1.0:
		return
	_samples += 1
	var deviation: float = absf(p.y - EntranceDirector.surface_y(p.z))
	if deviation > _worst_surface:
		_worst_surface = deviation
		_worst_surface_at = p
	if p.z <= ArenaBuilder.STAGE_FRONT or p.z >= EntranceDirector.RAMP_FOOT_Z:
		return
	_worst_drift = maxf(_worst_drift, absf(p.x))


## One shot per tag, the first time its beat is recognised.
func _maybe_shot(tag: String) -> void:
	if _shots.has(tag):
		return
	_shots[tag] = true
	get_viewport().get_texture().get_image().save_png(
			"%s_%s.%s" % [_out.get_basename(), tag, _out.get_extension()])
