class_name PostMatch
extends Node
## After the three (camera_aaa_plan.md C1-C4), the payoff 2K26 leans on
## hardest, cut as a broadcast cuts it:
##
##   the bell        the camera stays on the count and the reaction (HOLD)
##   C1 the winner   low and in front of him, up at him, the winner card over it
##   C2 the replay   the finisher again, half speed, from two new angles --
##                   mat level square to it, then high over it -- REPLAY
##                   badge up; skipped if replays are off or nothing to show
##   C3 celebration  close on him; ringside wide; the arena wide from under the
##                   rig; low and close as the referee raises his hand
##   C4 the rating   the match's stars over the arena wide
##
## Presentation only: the match is over and frozen when it starts. It drives
## MatchCamera through set_entrance_shot() (which takes the camera off its own
## logic) and plays the replay through ReplayBuffer, which hands every pose
## back afterwards.

signal finished

const HOLD := 1.8
const WINNER_HOLD := 3.0
const REPLAY_LEAD := 0.6     # seconds before the finisher starts
const REPLAY_TAIL := 0.9     # after the cover starts
const REPLAY_SPEED := 0.5
const CELEBRATION := [["close", 2.2], ["ringside", 2.0], ["arena", 2.6], ["hero", 2.4]]
const RATING_HOLD := 3.6

var camera: MatchCamera
var winner: WrestlerController
var loser: WrestlerController
var replay: ReplayBuffer
var stats := {}

var _t := 0.0
var _stage := "hold"
var _stage_t := 0.0
var _replay_from := -1.0
var _replay_to := -1.0
var _celeb := 0
var _layer: CanvasLayer
var _card: EntranceLowerThird
var _badge: Control
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
	_badge = _ReplayBadge.new()
	_badge.visible = false
	_layer.add_child(_badge)
	_rating = _RatingCard.new()
	_rating.visible = false
	(_rating as _RatingCard).stars = match_rating(stats)
	(_rating as _RatingCard).minutes = float(stats.get("seconds", 0.0)) / 60.0
	_layer.add_child(_rating)
	if replay and CameraSettings.replay_finish():
		var start := replay.mark_time("finisher")
		var cover := replay.mark_time("cover")
		if start >= 0.0:
			_replay_from = start - REPLAY_LEAD
			_replay_to = (cover if cover > start else start + 3.0) + REPLAY_TAIL
			if not replay.has_window(_replay_from, _replay_to):
				_replay_from = -1.0


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
		"hold":
			if _stage_t >= HOLD:
				_next("winner")
				_card.show_card(_name(winner), "WINNER")
		"winner":
			_shot_winner_low(delta)
			if _stage_t >= WINNER_HOLD:
				_card.hide_card()
				_next("replay" if _replay_from >= 0.0 else "celebrate")
				if _stage == "replay":
					replay.begin_playback()
					_badge.visible = true
		"replay":
			var length := (_replay_to - _replay_from) / REPLAY_SPEED
			var at := _replay_from + _stage_t * REPLAY_SPEED
			replay.show(at)
			_shot_replay(_stage_t / length, delta)
			if _stage_t >= length:
				replay.restore()
				_badge.visible = false
				_next("celebrate")
		"celebrate":
			var step: Array = CELEBRATION[_celeb]
			_shot_celebration(String(step[0]), delta)
			if _stage_t >= float(step[1]):
				_celeb += 1
				_stage_t = 0.0
				if _celeb >= CELEBRATION.size():
					_next("rating")
					_rating.visible = true
		"rating":
			_shot_celebration("arena", delta)
			if _stage_t >= RATING_HOLD:
				_rating.visible = false
				_done = true
				finished.emit()


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


## The finisher again: mat level and square to the pair for the first half,
## high over the downed man for the second.
func _shot_replay(k: float, delta: float) -> void:
	var a := winner.global_position
	var d := loser.global_position if loser else a
	var mid := (a + d) * 0.5
	var across := d - a
	across.y = 0.0
	if across.length() < 0.2:
		across = _front(winner)
	across = across.normalized()
	var side := Vector3.UP.cross(across).normalized()
	if side.dot(camera.hard_cam_position - mid) < 0.0:
		side = -side
	if k < 0.5:
		camera.set_entrance_shot(mid - side * 3.3 + Vector3.UP * 0.5, mid + Vector3.UP * 0.8,
				50.0, _stage_t <= delta * 1.5, delta)
	else:
		camera.set_entrance_shot(mid + side * 1.6 - across * 1.5 + Vector3.UP * 3.8,
				mid + Vector3.UP * 0.4, 46.0, absf(k - 0.5) < 0.02, delta)


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
			camera.set_entrance_shot(Vector3(-11.0, EntranceDirector.RIG_CLEAR_Y - 0.6, 6.0),
					p + Vector3.UP * 1.0, 48.0, snap, delta)
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
