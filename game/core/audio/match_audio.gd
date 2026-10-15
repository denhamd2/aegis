class_name MatchAudio
extends Node
## What the hall sounds like: the crowd, the bell, the hits, the referee's
## hand on the mat, the pyro. The entrance music is not here -- it is the
## audio track of each man's titantron video, which StageVideo plays.
##
## Presentation only, in the same way as CrowdReaction, and next to it: it
## listens to signals and reads state in _process, and writes nothing a match
## can read. Its sample picks come from SfxPool's own seeded generator, so a
## recording made under Movie Maker (fixed frame time) sounds the same twice.
##
## The mix is a broadcast mix, not a positional one: the crowd all round,
## hits and bumps up front, the way a TV feed carries ring mics.
##
## Sounds are built by tools/audio/build_sfx.py (CC0 sources, listed in
## assets/audio/CREDITS.md).

## The crowd is five loops of different lengths (52 / 23 / 41 s, so no seam
## is ever heard twice together) riding one slewed intensity, plus a roar on
## the excitement and, by who is hurting whom, boos or a cheer. Levels in dB
## at intensity 0 and 1; nothing steps, every layer slews to its target.
##
## Every loop is cut to the same loudness (build_sfx.CROWD_LUFS, -16 LUFS), so
## these numbers are the mix: about -21 LUFS of crowd in a quiet minute,
## -15 at full cry, with chants (CrowdChants) over the top. Read back off a
## recording by tools/audio/measure_mix.py.
const BED_DB := -5.0
const BED_EXCITED_DB := -1.0
const WALLA_A_DB := [-15.0, -5.0]
const WALLA_B_DB := [-28.0, -5.0]
const ROAR_MAX_DB := -3.0
## Below this the roar is off; it comes in on a curve so a jab does nothing.
const ROAR_FLOOR := 0.08
## How fast a layer's level closes on its target, per second.
const SLEW_RATE := 1.6
## The match builds: a quiet feeling-out, a room that has warmed by the
## PHASE_FULL second. Added under the excitement as a floor on the intensity.
const PHASE_FULL := 300.0
const PHASE_FLOOR_MAX := 0.32
## Boos and cheers die away by half every this many seconds.
const HEAT_HALF_LIFE := 4.5
const HEAT_ON_DB := -4.0
const HEAT_OFF_DB := -42.0

## A bump: the pelvis falling faster than this and then stopping, low.
const BUMP_FALL_SPEED := 2.0
const BUMP_FULL_SPEED := 5.5
const BUMP_STOP_SPEED := 0.6
## Pelvis height over the man's own feet when he has landed.
const BUMP_LOW := 0.6
const BUMP_COOLDOWN := 0.45
## How far back the fall is remembered while it lands, seconds.
const BUMP_WINDOW := 0.2

## Strikes by damage: a jab is quiet, a bionic elbow is not.
const HIT_DAMAGE_QUIET := 3.0
const HIT_DAMAGE_LOUD := 12.0

## Owner-supplied broadcast calls, cued by match events. Keep a short gap so
## Tony's reaction follows the handgun's muzzle report rather than masking it.
const COMMENTARY_CLIPS := {
	"gunshot": ["res://assets/audio/commentary/tony_gunshot.ogg"],
	"tony_danger_warning": ["res://assets/audio/commentary/tony_danger_warning.ogg"],
	"tony_roman_heel": ["res://assets/audio/commentary/tony_roman_heel.ogg"],
	"tony_title_match": ["res://assets/audio/commentary/tony_title_match.ogg"],
	"cody_return": ["res://assets/audio/commentary/tony_cody_return.ogg"],
	"excalibur_cody_career": ["res://assets/audio/commentary/excalibur_cody_career.ogg"],
	"roman_record": ["res://assets/audio/commentary/tony_roman_record.ogg"],
	"roman_spear": ["res://assets/audio/commentary/tony_roman_spear.ogg"],
	"excalibur_superman_punch": ["res://assets/audio/commentary/excalibur_superman_punch.ogg"],
	"excalibur_wednesday": ["res://assets/audio/commentary/excalibur_wednesday.ogg"],
	"excalibur_crowd": ["res://assets/audio/commentary/excalibur_crowd.ogg"],
	"excalibur_comeback": ["res://assets/audio/commentary/excalibur_comeback.ogg"],
	"excalibur_two_count": [
		"res://assets/audio/commentary/excalibur_two_count.ogg",
		"res://assets/audio/commentary/excalibur_kickout_one_seven_eighths.ogg",
	],
	"excalibur_finish": ["res://assets/audio/commentary/excalibur_finish.ogg"],
	"excalibur_coolest_job": ["res://assets/audio/commentary/excalibur_coolest_job.ogg"],
	"excalibur_signoff": ["res://assets/audio/commentary/excalibur_signoff.ogg"],
	"enda_easter_egg": ["res://assets/audio/commentary/tony_enda_easter_egg.ogg"],
	"tony_submission": ["res://assets/audio/commentary/tony_submission.ogg"],
	"tony_love_this_business": ["res://assets/audio/commentary/tony_love_this_business.ogg"],
	"tony_what_a_night": ["res://assets/audio/commentary/tony_what_a_night.ogg"],
	"tony_crowd_up": ["res://assets/audio/commentary/tony_crowd_up.ogg"],
}
const COMMENTARY_EVENT_DELAY := 0.18
const COMMENTARY_VOICE_DB := 0.0
const ENDA_EASTER_EGG_AFTER := 30.0
const ENDA_QUIET_HOLD := 1.0
const ENDA_CUTAWAY_TAIL := 0.5
const ENDA_CUTAWAY_WAIT_MAX := 3.0

## A move worth a pop of its own (CrowdReaction.move_pop at or over this).
const POP_MOVE := 0.45

var sfx: SfxPool
var _bed: AudioStreamPlayer
var _walla_a: AudioStreamPlayer
var _walla_b: AudioStreamPlayer
var _boo_loop: AudioStreamPlayer
var _cheer_loop: AudioStreamPlayer
var _roar: AudioStreamPlayer
## The slewed 0-1 driver of the beds, the match's clock, and the two heats.
var intensity := 0.0
var boo := 0.0
var cheer := 0.0
var _clock := 0.0
var _crowd: CrowdReaction
var _referee: MatchReferee
var _director: EntranceDirector
## When the building chants (CrowdChants).
var chants: CrowdChants
## The winner's theme, once the bell has gone: from his chorus, faded in, with
## the crowd beds ducked under it.
const THEME_DB := -3.0
const THEME_FADE_IN := 2.5
## Under music the crowd dips, it does not vanish: a live room is not turned
## down for a song.
const THEME_DUCK_DB := -4.0
var _theme: AudioStreamPlayer
var _theme_from := -1.0
var _theme_fade := 0.0
var _duck := 0.0
var _wrestlers: Array = []
var _pelvis := {}        # wrestler -> bone index
var _last_y := {}        # wrestler -> pelvis height last frame
var _falls := {}         # wrestler -> Array of [age, vy] this window
var _cooldown := {}      # wrestler -> seconds until he can bump again
var _count_heard := 0
var _was_pinning := false
var _over := false
var _commentary_voice: AudioStreamPlayer
var _voice_lane: RingAnnouncer
var _commentary_rng := RandomNumberGenerator.new()
var _commentary_events_played := {}
var _commentary_last_queued := {}
var _commentary_queue: Array[String] = []
var _commentary_delay := -1.0
var _commentary_clock := 0.0
var _enda_easter_egg_selected := false
var _enda_easter_egg_used := false
var _enda_easter_egg_waiting := false
var _enda_cutaway_hold := 0.0
var _enda_cutaway_wait := 0.0
var _enda_down_candidate: WrestlerController
var _enda_down_seconds := 0.0
var _sign_fans: SignFans
var _match_camera: MatchCamera


func _ready() -> void:
	sfx = SfxPool.new()
	sfx.name = "Sfx"
	add_child(sfx)
	add_to_group(WeaponActor.LISTENERS)
	chants = CrowdChants.new()
	chants.name = "Chants"
	chants.sfx = sfx
	add_child(chants)
	_bed = sfx.make_loop("crowd_bed")
	_walla_a = sfx.make_loop("crowd_walla_a")
	_walla_b = sfx.make_loop("crowd_walla_b")
	_boo_loop = sfx.make_loop("crowd_boo")
	_cheer_loop = sfx.make_loop("crowd_cheer")
	_roar = sfx.make_loop("crowd_roar")
	_bed.volume_db = BED_DB
	# Under the ring announcer when he speaks (RingAnnouncer.DUCK_DB).
	for p: AudioStreamPlayer in [_bed, _walla_a, _walla_b, _boo_loop, _cheer_loop, _roar]:
		p.bus = RingAnnouncer.under_bus()
	# Out of step from the first frame: each layer starts somewhere else in
	# its own loop (deterministic -- SfxPool's seeded generator, not the match's).
	for p: AudioStreamPlayer in [_bed, _walla_a, _walla_b, _boo_loop, _cheer_loop, _roar]:
		var length: float = p.stream.get_length()
		p.seek(fposmod(length * float(hash(String(p.name)) % 1000) / 1000.0, length))
	_commentary_voice = AudioStreamPlayer.new()
	_commentary_voice.name = "CommentaryVoice"
	_commentary_voice.bus = RingAnnouncer.voice_bus()
	_commentary_voice.volume_db = COMMENTARY_VOICE_DB
	add_child(_commentary_voice)


## Hooks the match up. Called by match_setup, beside CrowdReaction.watch().
func watch(referee: MatchReferee, wrestlers: Array, crowd: CrowdReaction, match_seed: int = 0) -> void:
	_referee = referee
	_crowd = crowd
	_wrestlers = wrestlers
	_enda_easter_egg_selected = enda_easter_egg_for_seed(match_seed)
	# Commentary choices are presentation-only, but a seeded stream keeps
	# replayed broadcasts consistent while still allowing alternate takes.
	_commentary_rng.seed = match_seed * 32771 + 4619
	for w: WrestlerController in wrestlers:
		w.move_landed.connect(_on_move_landed)
		w.weapon_taken.connect(_on_weapon_taken)
		w.fsm.state_changed.connect(_on_wrestler_state_changed)
		w.reversed.connect(func(_r, _s, _m): sfx.play("whoosh", -6.0))
		w.taunted.connect(_on_wrestler_taunted)
		w.fired_up.connect(_on_wrestler_fired_up)
		w.set_piece_landed.connect(_on_set_piece_landed)
		_cooldown[w] = 0.0
		_falls[w] = []
	referee.match_won.connect(_on_match_won)


## The entrances' cues (EntranceDirector.cue): the pyro, and the crowd as a
## man's music hits.
func follow(director: EntranceDirector) -> void:
	_director = director
	director.cue.connect(_on_cue)


func share_voice_lane(announcer: RingAnnouncer) -> void:
	_voice_lane = announcer


## Stable per match and independent of other commentary RNG draws: roughly one
## in three matches gets the sign gag, without introducing run-to-run noise.
static func enda_easter_egg_for_seed(match_seed: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 104729 + 8191
	return rng.randi_range(0, 2) == 0


## Excalibur signs off only after the complete post-match broadcast package.
func follow_post_match(post_match: PostMatch) -> void:
	post_match.finished.connect(_on_post_match_finished)


func _on_post_match_finished() -> void:
	_queue_commentary("tony_what_a_night")
	_queue_commentary("excalibur_signoff")


## The opening bell, whether after the entrances or on tick one.
func opening_bell() -> void:
	sfx.play("bell_start", -2.0)
	chants.bell()


func _on_cue(what: String) -> void:
	var commentary_event := commentary_event_for_cue(what)
	if commentary_event != "":
		_queue_commentary(commentary_event)
	if what == "excalibur_crowd":
		# Tony answers Excalibur's crowd read before either entrance begins.
		_queue_commentary("tony_crowd_up")
	if what == "cody_appear":
		# Excalibur answers Tony's Cody return call during Cody's entrance.
		_queue_commentary("excalibur_cody_career")
	match what:
		"pyro_stage", "pyro_over_ring":
			sfx.play("pyro_boom", -1.0)
		"pyro_roman":
			# Flame units: the roar of the fire under the boom.
			sfx.play("pyro_boom", -2.0)
			sfx.play("whoosh", -4.0)
		"pyro_cody_hit", "pyro_cody_punch":
			sfx.play("pyro_bang", -2.0)
			sfx.play("pyro_boom", -8.0)
		"strobe":
			sfx.play("pyro_bang", -6.0)
		"tron_on":
			# The music hits: the building goes up around the entrance.
			sfx.play_any("crowd_pop", -2.0)
			var who: WrestlerController = _director.entrance_owner() if _director else null
			if who:
				_heat(who, 1.0)


## Which sound a landed move makes the moment it lands, if any. Strikes and
## stomps connect on this tick; slams and throws land later, when the body
## does, and the bump detector hears that instead.
static func hit_sound(move: MoveDef) -> String:
	if move == null:
		return ""
	var weapon := WeaponCatalog.of_move(move)
	if weapon:
		# a gun, a launcher or a spray is heard as it goes off (on_weapon_event)
		if weapon.swing in [WeaponDef.Swing.GUN, WeaponDef.Swing.LAUNCHER, WeaponDef.Swing.SPRAY]:
			return ""
		return weapon.sound
	var file := move.resource_path.get_file().get_basename()
	if file.contains("kick") or file.contains("stomp") or file.contains("knee"):
		return "hit_kick"
	if file.begins_with("strike_") or file.begins_with("ground_") \
			or file.contains("punch") or file.contains("elbow") \
			or file.contains("clothesline") or file.contains("lariat"):
		return "hit_punch"
	return ""


static func hit_volume(move: MoveDef) -> float:
	var total := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	var t := clampf((total - HIT_DAMAGE_QUIET) / (HIT_DAMAGE_LOUD - HIT_DAMAGE_QUIET), 0.0, 1.0)
	return lerpf(-9.0, 0.0, t)


## A gun's muzzle flash is the broadcast cue; other flashes (if added later)
## must not inherit this line.
static func commentary_event_for_weapon(weapon_id: StringName, event: String) -> String:
	return "gunshot" if weapon_id == &"handgun" and event == "flash" else ""


static func commentary_event_for_weapon_ready(weapon_id: StringName) -> String:
	var weapon := WeaponCatalog.by_id(weapon_id)
	if weapon == null:
		return ""
	var exceptional_risk := weapon_id in [
		&"steel_chair", &"baseball_bat", &"ladder", &"light_tubes", &"barbed_wire_chair",
		&"barbed_wire_bat", &"bed_of_nails", &"barbed_wire_board",
	]
	return "tony_danger_warning" if (
		weapon.damage_head >= 12.0 or weapon.landing_damage >= 12.0 or exceptional_risk
	) else ""


static func commentary_event_for_heel_pose(entrance_style: String) -> String:
	return "tony_roman_heel" if entrance_style == "roman" else ""


static func commentary_event_for_roman_heel_attack(entrance_style: String, move: MoveDef) -> String:
	if entrance_style != "roman":
		return ""
	var weapon := WeaponCatalog.of_move(move)
	if weapon == null or commentary_event_for_weapon_ready(weapon.id) == "":
		return ""
	return "tony_roman_heel"


func _on_wrestler_taunted(who: WrestlerController) -> void:
	_heat(who, 0.5)
	sfx.play_any("crowd_pop", -9.0)
	var event := commentary_event_for_heel_pose(who.entrance_style)
	if event != "":
		_queue_commentary(event)


func _on_weapon_taken(_who: WrestlerController, weapon: WeaponActor) -> void:
	if weapon == null or weapon.def == null:
		return
	var event := commentary_event_for_weapon_ready(weapon.def.id)
	if event != "":
		_queue_commentary(event)


static func commentary_event_for_cue(cue: String) -> String:
	match cue:
		"cody_appear":
			return "cody_return"
		"broadcast_open":
			return "excalibur_wednesday"
		"title_match":
			return "tony_title_match"
		"excalibur_crowd":
			return "excalibur_crowd"
	return ""


static func commentary_event_for_state(state: int) -> String:
	return "tony_submission" if state == WrestlerFSM.State.SUBMISSION_ATTACKER else ""


static func commentary_events_for_kickout(count: int, match_over: bool) -> Array[String]:
	if count >= 2 and not match_over:
		return ["excalibur_two_count", "tony_love_this_business"]
	return []


func _on_wrestler_state_changed(_previous: int, current: int) -> void:
	var commentary_event := commentary_event_for_state(current)
	if commentary_event != "":
		_queue_commentary(commentary_event)


static func commentary_event_for_landed_move(entrance_style: String, move_id: String) -> String:
	if entrance_style != "roman":
		return ""
	if move_id == "signature_superman_punch":
		return "excalibur_superman_punch"
	return "roman_spear" if move_id == "finisher_spear" else "roman_record"


func _on_wrestler_fired_up(who: Variant) -> void:
	_heat(who, 0.7)
	sfx.play_any("crowd_pop", -6.0)
	_queue_commentary("excalibur_comeback")


func _queue_commentary(event: String, once_per_match := true, cooldown_seconds := 0.0) -> void:
	if not COMMENTARY_CLIPS.has(event):
		return
	var clips: Array = COMMENTARY_CLIPS[event]
	if clips.is_empty():
		return
	if once_per_match and _commentary_events_played.has(event):
		return
	if not once_per_match and _commentary_clock - float(_commentary_last_queued.get(event, -INF)) < cooldown_seconds:
		return
	if clips.all(func(path: String) -> bool: return not ResourceLoader.exists(path)):
		return
	if once_per_match:
		_commentary_events_played[event] = true
	_commentary_last_queued[event] = _commentary_clock
	_commentary_queue.append(event)


## Loudness of a bump from how fast he was falling, or NAN for no bump.
static func bump_volume(fall_speed: float) -> float:
	if fall_speed < BUMP_FALL_SPEED:
		return NAN
	var t := clampf((fall_speed - BUMP_FALL_SPEED) / (BUMP_FULL_SPEED - BUMP_FALL_SPEED), 0.0, 1.0)
	return lerpf(-10.0, 0.0, t)


## Who the house is behind: -1 for the heel (Roman Reigns), +1 for the face
## (Cody Rhodes), 0 for anyone else. By name, the way the roster presents them.
static func favor_of(display_name: String) -> float:
	return Persona.favor(display_name)


## The match's warm-up as a floor under the intensity: 0 at the bell, full by
## PHASE_FULL seconds, on a curve that is slow to begin with.
static func phase_floor(clock: float) -> float:
	return PHASE_FLOOR_MAX * smoothstep(0.0, 1.0, clock / PHASE_FULL)


## Each loop's target level for an intensity (0-1), by layer name.
static func bed_levels(i: float) -> Dictionary:
	i = clampf(i, 0.0, 1.0)
	return {
		"bed": lerpf(BED_DB, BED_EXCITED_DB, i),
		"walla_a": lerpf(WALLA_A_DB[0], WALLA_A_DB[1], i),
		"walla_b": lerpf(WALLA_B_DB[0], WALLA_B_DB[1], i * i),
	}


## A heat (boos or a cheer, 0-1) as a level: off below a whisper.
static func heat_db(heat: float) -> float:
	if heat < 0.02:
		return -80.0
	return lerpf(HEAT_OFF_DB, HEAT_ON_DB, clampf(heat, 0.0, 1.0))


## The heat after `delta` more seconds with nothing feeding it.
static func cool(heat: float, delta: float) -> float:
	return heat * pow(0.5, delta / HEAT_HALF_LIFE)


## Boos for the heel's doing, a cheer for the face's.
func _heat(who: Variant, amount: float) -> void:
	if who == null or not (who is WrestlerController):
		return
	var f := favor_of((who as WrestlerController).display_name)
	if f < 0.0:
		boo = minf(boo + amount, 1.0)
	elif f > 0.0:
		cheer = minf(cheer + amount, 1.0)


func _on_move_landed(attacker, _defender, move: MoveDef) -> void:
	_heat(attacker, 0.12 + 0.5 * CrowdReaction.move_pop(move))
	var sound := hit_sound(move)
	if sound != "" and not sfx.play_any(sound, hit_volume(move)):
		sfx.play(sound, hit_volume(move))      # a one-off: the bell, the whoosh
	var pop := CrowdReaction.move_pop(move)
	if pop >= POP_MOVE:
		sfx.play_any("crowd_pop", lerpf(-8.0, -2.0, clampf((pop - POP_MOVE) / (1.0 - POP_MOVE), 0.0, 1.0)))
	if attacker is WrestlerController:
		var move_id := move.resource_path.get_file().get_basename()
		var commentary_event := commentary_event_for_roman_heel_attack(
				attacker.entrance_style, move)
		if commentary_event == "":
			commentary_event = commentary_event_for_landed_move(attacker.entrance_style, move_id)
		if commentary_event != "":
			_queue_commentary(commentary_event)


## A weapon going off or breaking (WeaponActor.LISTENERS).
func on_weapon_event(weapon: WeaponActor, event: String) -> void:
	match event:
		"flash":
			sfx.play("pyro_bang", 0.0)
			sfx.play_any("crowd_ooh", -4.0)
			var commentary_event := commentary_event_for_weapon(weapon.def.id, event)
			if commentary_event != "":
				_queue_commentary(commentary_event)
		"cloud":
			sfx.play("whoosh", -2.0, 0.7)
		"rocket":
			sfx.play("whoosh", 0.0, 0.8)
			sfx.play("pyro_bang", -6.0, 0.7)
		"blast":
			sfx.play("pyro_boom", 0.0)
			sfx.play_any("crowd_ooh", -2.0)
		"set_up":
			if weapon.def.id == &"table":
				chants.table_set_up()
		"broke":
			if weapon.def.id == &"table":
				sfx.play_any("table_crack", 0.0)
			elif not sfx.play_any(weapon.def.sound, -1.0):
				sfx.play(weapon.def.sound, -1.0)


## Through a table: the crowd. (The crack itself is the table's "broke".)
func _on_set_piece_landed(who: WrestlerController, _weapon: WeaponActor, broke: bool) -> void:
	var by := who.opponent
	_heat(by, 0.8 if broke else 0.4)
	sfx.play_any("crowd_pop", -1.0 if broke else -5.0)
	sfx.play_any("crowd_ooh", -2.0 if broke else -4.0)


func _on_match_won(winner: Variant, method: String) -> void:
	_over = true
	chants.match_over(favor_of((winner as WrestlerController).display_name) if winner is WrestlerController else 0.0)
	# The three lands on the tick the match ends, before _process hears the
	# count: slap it here so the hand comes down before the bell, not after.
	if method == "pinfall" and _count_heard < 3:
		_count_heard = 3
		sfx.play_any("count_slap", -1.0)
		chants.count(3, sfx)
	sfx.play("bell_end", -1.0)
	sfx.play("crowd_finish", 0.0)
	_queue_commentary("excalibur_finish")
	_queue_commentary("excalibur_coolest_job")
	var w := winner as WrestlerController
	if w:
		winner_theme(w.entrance_style)


## The winner's music: his entrance song from its main part (StageVideo
## .chorus_at), not from the intro, fading in over THEME_FADE_IN. False when he
## has no theme. Any entrance music still up is the director's to fade.
func winner_theme(style: String) -> bool:
	var from := StageVideo.chorus_at(style)
	var path := StageVideo.music_path(style)
	if from < 0.0 or path == "" or not ResourceLoader.exists(path):
		return false
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		return false
	if _theme:
		_theme.queue_free()
	stream = stream.duplicate() as AudioStreamOggVorbis
	stream.loop = false
	_theme = AudioStreamPlayer.new()
	_theme.name = "WinnerTheme"
	_theme.stream = stream
	_theme.volume_db = -60.0
	add_child(_theme)
	_theme.play(from)
	_theme_from = from
	_theme_fade = 0.0
	return true


## "style-less" report for probes: where the winner's theme is, in song seconds.
func theme_info() -> String:
	if _theme == null:
		return "none"
	return "%.1fs from %.1f (%.0f dB)" % [_theme.get_playback_position() + _theme_from,
			_theme_from, _theme.volume_db]


func theme_player() -> AudioStreamPlayer:
	return _theme


func _process(delta: float) -> void:
	_commentary_clock += delta
	var voice_busy := _voice_lane.has_voice() if _voice_lane else _commentary_voice.playing
	if not _commentary_queue.is_empty() and not voice_busy:
		if _commentary_delay < 0.0:
			_commentary_delay = COMMENTARY_EVENT_DELAY
		_commentary_delay = maxf(0.0, _commentary_delay - delta)
		if _commentary_delay <= 0.0:
			var event: String = _commentary_queue.pop_front()
			var clips: Array = COMMENTARY_CLIPS[event]
			var available: Array[String] = []
			for clip: String in clips:
				if ResourceLoader.exists(clip):
					available.append(clip)
			if not available.is_empty():
				var choice := available[_commentary_rng.randi_range(0, available.size() - 1)]
				var stream := load(choice) as AudioStream
				if _voice_lane:
					_voice_lane.play_commentary(stream)
				else:
					_commentary_voice.stream = stream
					_commentary_voice.play()
			_commentary_delay = -1.0
			_commentary_delay = -1.0
	var excitement := _crowd.excitement if _crowd else 0.0
	if not _over:
		_clock += delta
	# The driver: the room's excitement over the match's warm-up, slewed so a
	# pop swells the beds and a lull lets them fall, never a step.
	var target := maxf(excitement, phase_floor(_clock))
	intensity = lerpf(intensity, target, 1.0 - exp(-delta * 1.2))
	boo = cool(boo, delta)
	cheer = cool(cheer, delta)
	var levels := bed_levels(intensity)
	if _theme:
		_theme_fade = minf(_theme_fade + delta / THEME_FADE_IN, 1.0)
		_theme.volume_db = lerpf(-40.0, THEME_DB, _theme_fade * _theme_fade)
		_duck = lerpf(_duck, THEME_DUCK_DB * _theme_fade, 1.0 - exp(-delta * 2.0))
	_slew(_bed, levels["bed"] + _duck, delta)
	_slew(_walla_a, levels["walla_a"] + _duck, delta)
	_slew(_walla_b, levels["walla_b"] + _duck, delta)
	_slew(_boo_loop, heat_db(boo), delta)
	_slew(_cheer_loop, heat_db(cheer), delta)
	if _roar:
		var level := clampf((excitement - ROAR_FLOOR) / (1.0 - ROAR_FLOOR), 0.0, 1.0)
		_roar.volume_db = ROAR_MAX_DB + linear_to_db(maxf(pow(level, 1.5), 0.0001))
	_hear_the_count()
	chants.tick(delta, excitement)
	for w: WrestlerController in _wrestlers:
		if is_instance_valid(w):
			_hear_bumps(w, delta)
	_try_enda_easter_egg(delta)


## A quiet, sustained knockdown is the setup. Cut only when the camera and
## shared commentator lane are free, so the sign and Tony's line land together.
func _try_enda_easter_egg(delta: float) -> void:
	if (
			not _enda_easter_egg_selected
			or _enda_easter_egg_used
	):
		return
	if _over:
		_cancel_enda_easter_egg()
		return
	if _clock < ENDA_EASTER_EGG_AFTER:
		return
	if _match_camera == null or not is_instance_valid(_match_camera):
		_match_camera = get_tree().get_first_node_in_group("match_camera") as MatchCamera
	if _sign_fans == null or not is_instance_valid(_sign_fans):
		_sign_fans = get_tree().get_first_node_in_group("sign_fans") as SignFans
	if _match_camera == null or _sign_fans == null:
		return
	if _enda_easter_egg_waiting:
		var enda_fan := _sign_fans.enda_easter_egg_fan()
		if (
				_enda_down_candidate == null
				or not is_instance_valid(_enda_down_candidate)
				or _enda_down_candidate.fsm.current_state != WrestlerFSM.State.DOWN
				or (_referee != null and _referee.is_pin_active())
		):
			_cancel_enda_easter_egg()
			return
		if enda_fan == null or enda_fan.stage != SignFan.Stage.HOLDING:
			return
		_enda_cutaway_wait += delta
		if _enda_cutaway_wait > ENDA_CUTAWAY_WAIT_MAX:
			_cancel_enda_easter_egg()
			_enda_down_seconds = 0.0
			return
		var voice_busy := _voice_lane.has_voice() if _voice_lane else _commentary_voice.playing
		if not _commentary_queue.is_empty() or voice_busy:
			_sign_fans.raise_enda_easter_egg(_enda_cutaway_hold)
			return
		if _match_camera.request_enda_sign_cutaway(_enda_cutaway_hold):
			_queue_commentary("enda_easter_egg")
			_enda_easter_egg_used = true
			_enda_easter_egg_waiting = false
		else:
			_sign_fans.raise_enda_easter_egg(_enda_cutaway_hold)
		return
	var down: WrestlerController
	for candidate: WrestlerController in _wrestlers:
		if (
				candidate != null
				and is_instance_valid(candidate)
				and candidate.fsm.current_state == WrestlerFSM.State.DOWN
		):
			if down != null:
				_enda_down_candidate = null
				_enda_down_seconds = 0.0
				return
			down = candidate
	if down == null:
		_enda_down_candidate = null
		_enda_down_seconds = 0.0
		return
	if down != _enda_down_candidate:
		_enda_down_candidate = down
		_enda_down_seconds = 0.0
	_enda_down_seconds += delta
	if _enda_down_seconds < ENDA_QUIET_HOLD:
		return
	if _referee == null or _referee.is_pin_active() or not _commentary_queue.is_empty():
		return
	var voice_busy := _voice_lane.has_voice() if _voice_lane else _commentary_voice.playing
	if voice_busy:
		return
	if (
			_sign_fans.enda_easter_egg_fan() == null
			or not _match_camera.can_request_enda_sign_cutaway()
	):
		return
	var stream := load(COMMENTARY_CLIPS["enda_easter_egg"][0]) as AudioStream
	if stream == null:
		return
	_enda_cutaway_hold = stream.get_length() + COMMENTARY_EVENT_DELAY + ENDA_CUTAWAY_TAIL
	if not _sign_fans.raise_enda_easter_egg(_enda_cutaway_hold):
		return
	_enda_cutaway_wait = 0.0
	_enda_easter_egg_waiting = true


func _cancel_enda_easter_egg() -> void:
	if _enda_easter_egg_waiting and _sign_fans != null and is_instance_valid(_sign_fans):
		_sign_fans.cancel_enda_easter_egg()
	_enda_easter_egg_waiting = false
	_enda_cutaway_wait = 0.0


func _slew(p: AudioStreamPlayer, db: float, delta: float) -> void:
	if p:
		p.volume_db = lerpf(p.volume_db, db, 1.0 - exp(-delta * SLEW_RATE))


func _hear_the_count() -> void:
	if _referee == null or not is_instance_valid(_referee):
		return
	var pinning := _referee.is_pin_active()
	if pinning and not _was_pinning:
		_count_heard = 0
	# Read whether or not the cover is still on: the three and the end of
	# the pin land on the same tick, and the count is held up after it.
	var count := _referee.pin_count()
	if count > _count_heard:
		_count_heard = count
		sfx.play_any("count_slap", -1.0)
		chants.count(count, sfx)
	if not pinning and _was_pinning and _count_heard >= 2 and not _over:
		chants.kicked_out(_count_heard)
		# A kickout after two: the gasp. (A three is the bell, not this.)
		sfx.play_any("crowd_ooh", -3.0)
		sfx.play_any("crowd_pop", -4.0)
	var events := commentary_events_for_kickout(_count_heard, _over)
	if not pinning and _was_pinning:
		for event: String in events:
			_queue_commentary(event)
	_was_pinning = pinning


func _hear_bumps(w: WrestlerController, delta: float) -> void:
	if delta <= 0.0 or w.skeleton == null:
		return
	if not _pelvis.has(w):
		_pelvis[w] = w.skeleton.find_bone(w._skeleton_bone_name("pelvis"))
	var bone: int = _pelvis[w]
	if bone < 0:
		return
	var y := (w.skeleton.global_transform * w.skeleton.get_bone_global_pose(bone).origin).y
	_cooldown[w] = maxf(0.0, float(_cooldown[w]) - delta)
	if not _last_y.has(w):
		_last_y[w] = y
		return
	var vy := (y - float(_last_y[w])) / delta
	_last_y[w] = y
	var falls: Array = _falls[w]
	for f: Array in falls:
		f[0] += delta
	while not falls.is_empty() and float(falls[0][0]) > BUMP_WINDOW:
		falls.pop_front()
	falls.append([0.0, vy])
	if _cooldown[w] > 0.0 or vy < -BUMP_STOP_SPEED:
		return
	if y - w.global_position.y > BUMP_LOW:
		return
	var fastest := 0.0
	for f: Array in falls:
		fastest = maxf(fastest, -float(f[1]))
	var db := bump_volume(fastest)
	if is_nan(db):
		return
	sfx.play_any("bump", db, 0.06)
	_cooldown[w] = BUMP_COOLDOWN
	falls.clear()
