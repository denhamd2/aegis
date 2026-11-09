class_name PostMatch
extends Node
## The finish goes straight to the winner and celebration, then the rating.
## The match is already frozen. Ending replays are deliberately omitted;
## InstantReplay retains its separate in-match settings and shared badge.

signal finished

const WINNER_HOLD := 3.0
const CELEBRATION := [["close", 2.2], ["ringside", 2.0], ["arena", 2.6], ["hero", 2.4]]
## The owner, 9 Nov: "For the post match celebration, instead of Aubrey
## raising their hand, have them climb a turnbuckle and celebrate, basically
## like they do during their entrance." He walks to the nearest corner clear
## of the loser, climbs to the second rope facing out (EntranceDirector's
## corner beats: CORNER_ROOT_M off the pad, the same climb, pose and step
## down), then the celebration shots and, in a title match, the belt.
const CORNER_WALK_SPEED := 1.3
const CORNER_TURN := 0.5
const CORNER_CLIMB := 1.2
const CORNER_POSE := 3.6
const CORNER_DOWN := 1.0
const CORNER_WALK_CLIP := "strikes/entrance_walk"
## The loser's body keeps a corner this far clear of him.
const CORNER_CLEAR := 1.4
var _corner_plan: Array = []
var _corner_step := 0
var _corner_from := Vector3.ZERO
var _corner_stand := Vector3.ZERO
var _corner_out := Vector3.ZERO
const RATING_HOLD := 3.6
## The title presented (TitlePresentation): the celebration holds on him and
## Aubrey until he has it up, then a last close shot of him with it.
const TITLE_HOLD := 2.6
var _title: TitlePresentation
var _title_t := 0.0

var camera: MatchCamera
var winner: WrestlerController
var loser: WrestlerController
var replay: ReplayBuffer
var stats := {}

var _t := 0.0
var _stage := "winner"
var _stage_t := 0.0
var _celeb := 0
var _layer: CanvasLayer
var _card: EntranceLowerThird
var _rating: Control
var _done := false


func begin(p_camera: MatchCamera, p_winner: WrestlerController, p_loser: WrestlerController,
		p_replay: ReplayBuffer, p_stats: Dictionary) -> void:
	camera = p_camera
	winner = p_winner
	loser = p_loser
	replay = p_replay
	stats = p_stats
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_card = EntranceLowerThird.new()
	_layer.add_child(_card)
	_rating = _RatingCard.new()
	_rating.visible = false
	(_rating as _RatingCard).stars = match_rating(stats)
	(_rating as _RatingCard).minutes = float(stats.get("seconds", 0.0)) / 60.0
	_layer.add_child(_rating)
	_card.show_card(_name(winner), "WINNER")
	_shot_winner_low(0.0)
	_plan_corner()


func is_done() -> bool:
	return _done


## Stars, 1 to 5 in quarters, from what the match had in it: its length,
## near-falls (the drama), reversals, and the big moves landed.
static func match_rating(s: Dictionary) -> float:
	var r := 2.25
	r += clampf((float(s.get("seconds", 0.0)) - 60.0) / 240.0, 0.0, 1.0) * 0.75
	r += minf(int(s.get("near_falls", 0)) * 0.4, 1.0)
	r += minf(int(s.get("reversals", 0)) * 0.08, 0.6)
	r += minf(int(s.get("big_moves", 0)) * 0.15, 0.6)
	return clampf(snappedf(r, 0.25), 1.0, 5.0)


func _process(delta: float) -> void:
	if camera == null or winner == null or _done:
		return
	_t += delta
	_stage_t += delta
	match _stage:
		"winner":
			_shot_winner_low(delta)
			if _stage_t >= WINNER_HOLD:
				_card.hide_card()
				_next("corner" if not _corner_plan.is_empty() else "celebrate")
				_start_corner_step()
		"corner":
			_run_corner(delta)
		"celebrate":
			var step: Array = CELEBRATION[_celeb]
			_shot_celebration(String(step[0]), delta)
			if _stage_t >= float(step[1]):
				_celeb += 1
				_stage_t = 0.0
				if _celeb >= CELEBRATION.size():
					if _title == null:
						_present_title()
					if _title != null and not _title.is_done():
						_celeb = CELEBRATION.size() - 1
						_next("title")
					else:
						_next("rating")
						_rating.visible = true
		"title":
			# held on him and Aubrey as she brings it, then on him with it up
			_shot_celebration("ringside" if not _title.is_done() else "close", delta)
			if _title.is_done():
				_title_t += delta
				if _title_t >= TITLE_HOLD:
					_next("rating")
					_rating.visible = true
		"rating":
			_shot_celebration("arena", delta)
			if _stage_t >= RATING_HOLD:
				_rating.visible = false
				_done = true
				finished.emit()


## The nearest corner whose pad is clear of the loser, and the beats to
## climb it. Empty (he celebrates where he stands) without a ring to climb.
func _plan_corner() -> void:
	if winner == null or not winner.has_method("play_presentation_clip"):
		return
	var p := winner.global_position
	var best := Vector2.ZERO
	var best_d := INF
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var pad := Vector3(corner.x, 0.0, corner.y) * RingBuilder.TURNBUCKLE_PAD_XZ
		if loser != null and Vector2(loser.global_position.x - pad.x,
				loser.global_position.z - pad.z).length() < CORNER_CLEAR:
			continue
		var d := Vector2(p.x - pad.x, p.z - pad.z).length()
		if d < best_d:
			best_d = d
			best = corner
	if best == Vector2.ZERO:
		return
	_corner_out = RingBuilder.step_out_dir(best)
	var pad := Vector3(best.x, 0.0, best.y) * RingBuilder.TURNBUCKLE_PAD_XZ
	_corner_stand = pad - _corner_out * EntranceDirector.CORNER_ROOT_M
	_corner_stand.y = p.y
	_corner_from = p
	var walk := Vector2(_corner_stand.x - p.x, _corner_stand.z - p.z).length() / CORNER_WALK_SPEED
	_corner_plan = [["walk", CORNER_WALK_CLIP, maxf(walk, 0.3)],
			["turn", CORNER_WALK_CLIP, CORNER_TURN],
			["climb", "strikes/corner_climb", CORNER_CLIMB],
			["pose", corner_pose_clip(winner), CORNER_POSE],
			["down", "strikes/corner_down", CORNER_DOWN]]


## His own corner pose from his entrance.
static func corner_pose_clip(w: WrestlerController) -> String:
	if w != null and w.entrance_style == "kenny":
		return "strikes/kenny_corner_wings"
	return "strikes/corner_pose"


func _start_corner_step() -> void:
	if _stage != "corner":
		return
	if _corner_step >= _corner_plan.size():
		_next("celebrate")
		return
	var step: Array = _corner_plan[_corner_step]
	# Out of the VICTORY clip on the first, then clip to clip.
	winner.play_presentation_clip(String(step[1]), _corner_step == 0)


func _run_corner(delta: float) -> void:
	var step: Array = _corner_plan[_corner_step]
	var t := clampf(_stage_t / float(step[2]), 0.0, 1.0)
	match String(step[0]):
		"walk":
			var at := _corner_from.lerp(_corner_stand, t)
			var dir := _corner_stand - _corner_from
			dir.y = 0.0
			winner.global_position = at
			if dir.length() > 0.05:
				winner.rotation.y = rotate_toward(winner.rotation.y,
						atan2(-dir.x, -dir.z), EntranceDirector.TURN_RATE * delta)
			# Not "ringside": that sits out past the corner he is walking
			# to, and its post hid him.
			_shot_celebration("close", delta)
		_:
			winner.global_position = _corner_stand
			# Facing out over the crowd, as on the way in.
			winner.rotation.y = rotate_toward(winner.rotation.y,
					atan2(-_corner_out.x, -_corner_out.z), EntranceDirector.TURN_RATE * delta)
			_shot_corner(delta)
	if _stage_t >= float(step[2]):
		_corner_step += 1
		_stage_t = 0.0
		_start_corner_step()


## Out past the post in front of him, below his feet, up at him on the ropes.
func _shot_corner(delta: float) -> void:
	var p := _corner_stand
	var right := Vector3.UP.cross(_corner_out).normalized()
	var at := p + _corner_out * 3.4 + right * 0.9 + Vector3.UP * 1.0
	camera.set_entrance_shot(at, _head(winner) + Vector3.DOWN * 0.1, 38.0,
			_stage_t <= delta * 1.5 and _corner_step == 2, delta)


## The belt to the winner during the uninterrupted celebration.
func _present_title() -> void:
	_title = TitlePresentation.of(self)
	var ref := get_parent().get_node_or_null("RefereeActor") as RefereeActor if get_parent() else null
	if _title and ref and _title.step == TitlePresentation.Step.ON_TABLE:
		_title.present(winner, ref)


func _next(stage: String) -> void:
	_stage = stage
	_stage_t = 0.0


static func _name(w: WrestlerController) -> String:
	return w.display_name if w.display_name != "" else String(w.name)


func _head(w: Node3D) -> Vector3:
	var wc := w as WrestlerController
	if wc:
		var h: Vector3 = wc._bone_world("Head")
		if h != Vector3.INF:
			return h
	return w.global_position + Vector3.UP * 1.65


## Toward the hard camera's side of him, so no cut jumps the line.
func _front(w: Node3D) -> Vector3:
	var f := -w.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var to_cam := camera.hard_cam_position - w.global_position
	to_cam.y = 0.0
	if f.dot(to_cam) < -0.3:
		f = to_cam.normalized()
	return f


func _shot_winner_low(delta: float) -> void:
	var p := winner.global_position
	var f := _front(winner)
	var right := Vector3.UP.cross(-f).normalized()
	camera.set_entrance_shot(p + f * 2.6 + right * 0.6 + Vector3.UP * 0.45,
			_head(winner) + Vector3.DOWN * 0.15, 34.0, _stage_t <= delta * 1.5, delta)


func _shot_celebration(kind: String, delta: float) -> void:
	var p := winner.global_position
	var f := _front(winner)
	var right := Vector3.UP.cross(-f).normalized()
	var snap := _stage_t <= delta * 1.5
	match kind:
		"close":
			camera.set_entrance_shot(p + f * 2.0 - right * 0.7 + Vector3.UP * 1.55,
					_head(winner), 30.0, snap, delta)
		"ringside":
			var at := Vector3(signf(p.x + 0.001) * 4.6, 1.3, signf(p.z + 0.001) * 4.6)
			camera.set_entrance_shot(at, p + Vector3.UP * 1.3, 44.0, snap, delta)
		"arena":
			# From the hard camera's side, under the rig (EntranceDirector.RIG_CLEAR_Y).
			var high := Vector3(-11.0, EntranceDirector.RIG_CLEAR_Y - 0.6, 6.0)
			camera.set_entrance_shot(high, EntranceDirector.rig_clear_look(high,
					p + Vector3.UP * 1.0, 48.0), 48.0, snap, delta)
		_:
			camera.set_entrance_shot(p + f * 1.7 + right * 0.4 + Vector3.UP * 0.35,
					_head(winner) + Vector3.UP * 0.2, 46.0, snap, delta)


## The REPLAY badge: a gold-edged black tab, top left.
class _ReplayBadge extends Control:
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := get_viewport_rect().size
		var h := s.y * 0.06
		var r := Rect2(s.x * 0.04, s.y * 0.06, h * 3.6, h)
		draw_rect(r, Color(0.04, 0.04, 0.05, 0.92))
		draw_rect(Rect2(r.position, Vector2(h * 0.12, h)), Color(1.0, 0.8, 0.24))
		var font := ThemeDB.fallback_font
		var size := int(h * 0.55)
		draw_string(font, r.position + Vector2(h * 0.35, h * 0.72), "REPLAY",
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1))
		# The record dot, blinking.
		if int(Time.get_ticks_msec() / 500) % 2 == 0:
			draw_circle(r.position + Vector2(r.size.x - h * 0.4, h * 0.5), h * 0.14, Color(0.9, 0.1, 0.1))


## The match rating: stars and the match time, centred low.
class _RatingCard extends Control:
	var stars := 3.0
	var minutes := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := get_viewport_rect().size
		var w := s.x * 0.36
		var h := s.y * 0.16
		var r := Rect2((s.x - w) * 0.5, s.y * 0.74, w, h)
		draw_rect(r, Color(0.03, 0.03, 0.04, 0.9))
		draw_rect(Rect2(r.position, Vector2(w, h * 0.05)), Color(1.0, 0.8, 0.24))
		var font := ThemeDB.fallback_font
		var title_size := int(h * 0.2)
		draw_string(font, r.position + Vector2(0, h * 0.32), "MATCH RATING",
				HORIZONTAL_ALIGNMENT_CENTER, w, title_size, Color(1.0, 0.8, 0.24))
		var star_r := h * 0.14
		var y := r.position.y + h * 0.6
		for i in 5:
			var cx := r.position.x + w * 0.5 + (i - 2) * star_r * 2.6
			var fill := clampf(stars - i, 0.0, 1.0)
			_star(Vector2(cx, y), star_r, Color(0.3, 0.3, 0.32))
			if fill > 0.0:
				_star(Vector2(cx, y), star_r * (0.4 + 0.6 * fill), Color(1.0, 0.8, 0.24))
		draw_string(font, r.position + Vector2(0, h * 0.92), "%.2f  |  %d:%02d" % [stars,
				int(minutes), int(fmod(minutes * 60.0, 60.0))],
				HORIZONTAL_ALIGNMENT_CENTER, w, int(h * 0.15), Color(0.9, 0.9, 0.9))

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2.0 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, col)
