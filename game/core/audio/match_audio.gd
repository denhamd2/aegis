class_name MatchAudio
extends Node
signal commentary_started(speaker: String, duration: float)
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
## these numbers are the mix. This pass lifts the beds and crowd reactions
## 3 dB over their previous level.
## A lift across the crowd layers: the broadcast mix read as too quiet during
## actual play -- +3 dB, and another +4 dB on the owner's word (19 Oct: "I want
## the crowd noise to be louder during the match"). Commentary stays on its
## separate voice bus; the master compressor and limiter hold the sum.
## The owner, 2 Nov: "way too quiet ... much more lively and loud in general
## throughout": +2 dB more across the loops.
## The owner, later the same day: "I still heard that crappy crowd audio
## throughout where it sounds like either someone talking or distant on a
## megaphone. Remove that completely and just use wrestling crowd audio."
## The bed, the walla layer over it and the swell had all been one hall walla
## recording -- a crowd talking. The walla layer is gone and the bed and the
## swell are rebuilt from the cheering, roaring and popping recordings only
## (tools/audio/build_crowd_beds.py). The bed takes the walla's place at rest.
const CROWD_MIX_GAIN_DB := 9.0
const BED_DB := -3.0
const BED_EXCITED_DB := 0.0
## The excitement layer, crowd_swell: cheers and pops rising with the match.
const SWELL_DB := [-24.0, -4.0]
## The crowd's one-shot reactions -- pops, oohs, the finish -- ride over the
## loops. They never had the loops' CROWD_MIX_GAIN_DB, so a big pop played
## about 3 dB under the bed it was meant to burst out of.
const CROWD_REACTION_GAIN_DB := 7.0
const ROAR_MAX_DB := -3.0
## Below this the roar is off; it comes in on a curve so a jab does nothing.
const ROAR_FLOOR := 0.08
## How fast a layer's level closes on its target, per second.
const SLEW_RATE := 1.6
## The match builds: a quiet feeling-out, a room that has warmed by the
## PHASE_FULL second. Added under the excitement as a floor on the intensity.
## The house is already up at the bell (PHASE_START) -- the owner wanted it
## lively throughout -- and warmer still once the match is going.
const PHASE_FULL := 240.0
const PHASE_START := 0.22
const PHASE_FLOOR_MAX := 0.55
## Boos and cheers die away by half every this many seconds.
const HEAT_HALF_LIFE := 4.5
const HEAT_ON_DB := -4.0
const HEAT_OFF_DB := -42.0

## No Holds Barred signature weapons need to cut through the crowd and bumps.
## The master bus compressor and limiter contain the summed peak safely.
const GUNSHOT_DB := 6.0
const ROCKET_LAUNCH_DB := 4.0
const ROCKET_IGNITION_DB := 0.0
const ROCKET_BLAST_DB := 6.0
## Entrance pyro needs to read over entrance music and the crowd. A +6 dB
## lift doubles the signal amplitude; the master compressor and limiter keep
## stacked bursts from clipping.
const ENTRANCE_PYRO_BOOST_DB := 6.0
## The opening and finish bells ring at the pitch they were recorded at: a
## 919 Hz ring bell. (They used to play at double speed, an octave up, for a
## quick bright cue; that also halved a 7-10 s ring. The quickness is now in
## the files -- the tails are faded to 4.3 s and 5.7 s by
## tools/audio/build_sfx_round4.py -- and the bell is a bell again.)
const MATCH_BELL_PITCH_SCALE := 1.0

## Steel and glass are bright and peaky: at the -1.5 dB ceiling their files
## come out at -23 LUFS-loop, 3 LU under the kendo stick, the sledge and the
## wood. The other 3 dB is added here, wherever they play. No more than 3: the
## master limiter would start ducking the crowd on every chair shot.
const HIT_TRIM_DB := {"hit_metal": 3.0, "hit_glass": 3.0}

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
	"tony_barbed_wire_chair": ["res://assets/audio/commentary/tony_barbed_wire_chair.ogg"],
	"excalibur_bed_of_nails": ["res://assets/audio/commentary/excalibur_bed_of_nails.ogg"],
	"tony_roman_heel": ["res://assets/audio/commentary/tony_roman_heel.ogg"],
	"tony_title_match": ["res://assets/audio/commentary/tony_title_match.ogg"],
	"cody_return": ["res://assets/audio/commentary/tony_cody_return.ogg"],
	# Tony on Kenny walking out, after Justin has called him (the owner's
	# clip, 26 Oct): "Look at him. Just look at the focus in the eyes of
	# Kenny Omega ..."
	"tony_kenny_focus": ["res://assets/audio/commentary/tony_kenny_focus.ogg"],
	# And Excalibur straight after him (26 Oct): "Indeed, Tony. A man whose
	# big-match resume speaks entirely for itself ..."
	"excalibur_kenny_resume": ["res://assets/audio/commentary/excalibur_kenny_resume.ogg"],
	"excalibur_cody_career": ["res://assets/audio/commentary/excalibur_cody_career.ogg"],
	"roman_record": ["res://assets/audio/commentary/tony_roman_record.ogg"],
	"roman_spear": ["res://assets/audio/commentary/tony_roman_spear.ogg",
			"res://assets/audio/commentary/tony_otc_spear.ogg"],
	"excalibur_superman_punch": ["res://assets/audio/commentary/excalibur_superman_punch.ogg"],
	"excalibur_strikes": ["res://assets/audio/commentary/excalibur_strikes.ogg"],
	"excalibur_body_kicks": ["res://assets/audio/commentary/excalibur_body_kicks.ogg"],
	"excalibur_unbelievable": ["res://assets/audio/commentary/excalibur_unbelievable.ogg"],
	"excalibur_restore_order": ["res://assets/audio/commentary/excalibur_restore_order.ogg"],
	"tony_momentum_shift": ["res://assets/audio/commentary/tony_momentum_shift.ogg"],
	"tony_tension": ["res://assets/audio/commentary/tony_tension.ogg"],
	"tony_sneaky_heel_easter_egg": ["res://assets/audio/commentary/tony_sneaky_heel_easter_egg.ogg"],
	"excalibur_wednesday": ["res://assets/audio/commentary/excalibur_wednesday.ogg"],
	"tony_welcome": ["res://assets/audio/commentary/tony_welcome.ogg"],
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
	# The owner's fire calls (13 Nov): Excalibur as a man goes up (ManFire.
	# ignited), and relieved once Aubrey has put him out (ManFire.extinguished).
	"excalibur_on_fire": ["res://assets/audio/commentary/excalibur_on_fire.ogg"],
	"excalibur_thank_aubrey": ["res://assets/audio/commentary/excalibur_thank_aubrey.ogg"],
	# On the dives (DiveSpot.on_dive_landed) and the Cody Cutter, standing or
	# off the springboard (13 Nov).
	"excalibur_tope_suicida": ["res://assets/audio/commentary/excalibur_tope_suicida.ogg"],
	"excalibur_cody_cutter": ["res://assets/audio/commentary/excalibur_cody_cutter.ogg"],
	# Cody going into his Figure Four (13 Nov), in place of Tony's generic
	# submission call.
	"excalibur_cody_figure_four": ["res://assets/audio/commentary/excalibur_cody_figure_four.ogg"],
	# The owner-supplied Tony line (worried and reserved): "The American
	# Nightmare is bleeding profusely, refusing to stay down."
	"tony_american_nightmare_blood": ["res://assets/audio/commentary/tony_american_nightmare_blood.ogg"],
	# "Look at the carnage!" -- Tony's awed call as the ring fills with chaos.
	"tony_carnage": ["res://assets/audio/commentary/tony_carnage.ogg"],
	# "Excalibur, I don't even know what to say to that." -- Tony, caught off
	# guard and searching for words, after an unbelievable spot.
	"tony_speechless": ["res://assets/audio/commentary/tony_speechless.ogg"],
	# "No! No! He kicked out! How did he kick out of that?" -- Tony's
	# disbelief at a dramatic late kick-out at two.
	"tony_dramatic_kickout": ["res://assets/audio/commentary/tony_dramatic_kickout.ogg"],
	# "Look at the blood! Look at the intensity!" -- Tony as a man bleeds.
	"tony_blood_intensity": ["res://assets/audio/commentary/tony_blood_intensity.ogg"],
	# "Watch out! Behind you!" -- Tony on a blindside hit from behind.
	"tony_watch_out_behind": ["res://assets/audio/commentary/tony_watch_out_behind.ogg"],
	# "He got him! He got him! One, two, three!" -- the pinfall-win call.
	"tony_pinfall_win": ["res://assets/audio/commentary/tony_pinfall_win.ogg"],
	# "I'm so sick of this guy." -- Tony's snark at a heel lording it over a
	# man he has already put down.
	"tony_sick_of_this_guy": ["res://assets/audio/commentary/tony_sick_of_this_guy.ogg"],
}
## The calls on something happening right now: they go to the head of the
## queue, so the fire call is not still waiting behind a long line when Aubrey
## has already put him out.
const COMMENTARY_LIVE_CALLS := ["excalibur_on_fire", "excalibur_tope_suicida",
		"excalibur_cody_cutter"]
## The moves Excalibur calls the Cody Cutter on.
const CODY_CUTTER_MOVES := ["signature_cody_cutter", "dive_springboard_cutter"]
## What DiveSpot calls when a dive lands (call_group, as the camera's trauma).
const LISTENERS := "match_audio"
const COMMENTARY_EVENT_DELAY := 0.18
const COMMENTARY_VOICE_DB := 0.0
## These are live-play calls that naturally fit more than one moment in a
## match. Keep a longer per-line gap for signature calls and the big
## "Unbelievable" reaction, plus a shared gap so different punch/kick calls
## do not turn into a constant commentary loop.
const COMMENTARY_REPEAT_COOLDOWNS := {
	"roman_spear": 45.0,
	"excalibur_superman_punch": 35.0,
	"excalibur_strikes": 22.0,
	"excalibur_body_kicks": 22.0,
	"excalibur_unbelievable": 60.0,
	"excalibur_cody_cutter": 45.0,
	"tony_american_nightmare_blood": 45.0,
	"tony_carnage": 45.0,
	"tony_speechless": 60.0,
	"tony_dramatic_kickout": 60.0,
	"tony_blood_intensity": 60.0,
	"tony_watch_out_behind": 30.0,
	"tony_sick_of_this_guy": 45.0,
}
const COMMENTARY_REPEAT_MIN_GAP := 12.0
const CODY_CROWD_CHANT := "res://assets/audio/crowd_cody_chant.ogg"
## The owner's other chants (CrowdChants): Roman's two, and the building's
## "This is awesome!" -- not before THIS_IS_AWESOME_FROM seconds in.
const ROMAN_CROWD_CHANTS := {"otc": "res://assets/audio/crowd_otc_chant.ogg",
		"fu_roman": "res://assets/audio/crowd_fu_roman_chant.ogg"}
const THIS_IS_AWESOME_CHANT := "res://assets/audio/crowd_this_is_awesome_chant.ogg"
const THIS_IS_AWESOME_FROM := 150.0
const ENDA_EASTER_EGG_AFTER := 15.0
const ENDA_QUIET_HOLD := 0.75
const ENDA_CUTAWAY_TAIL := 0.5

## A move worth a pop of its own (CrowdReaction.move_pop at or over this).
const POP_MOVE := 0.45
const UNBELIEVABLE_LATE_MATCH_AFTER := 240.0
const UNBELIEVABLE_SPECTACULAR_POP := 0.8
const CHAOS_COMMENTARY_THRESHOLD := 3.0
const CHAOS_COMMENTARY_DECAY_PER_SECOND := 0.2
## The shown blood level at which Tony calls "Look at the blood!" -- once per
## wrestler per match, so it lands as a moment rather than a running tally.
const BLOOD_CALL_AT := 0.55

var sfx: SfxPool
var _bed: AudioStreamPlayer
var _swell: AudioStreamPlayer
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
const THEME_DB := 0.0
const THEME_FADE_IN := 2.5
## The owner-supplied Dynamite broadcast theme starts under the opening
## announcers; at -3 dB it is 6 dB above its title-screen menu level.
const DYNAMITE_OPENING_THEME := "res://assets/audio/music/title_theme.ogg"
const DYNAMITE_OPENING_THEME_DB := -3.0
const DYNAMITE_OPENING_FADE_IN := 1.0
const DYNAMITE_OPENING_FADE_OUT := 1.5
## Hell in a Cell's lowering music (the owner, 11 Nov: "play the attached
## music when the cell is lowering (no looping)"): owner-supplied, from the
## first inch of the descent, once through; it runs on under the face-off and
## fades out at the bell. The crowd ducks under it as under an entrance song.
const CELL_MUSIC := "res://assets/audio/music/cell_lowering.ogg"
const CELL_MUSIC_DB := 0.0
const CELL_MUSIC_FADE_OUT := 2.0
var _cell_music: AudioStreamPlayer
var _cell_music_fade := -1.0


func _start_cell_music() -> void:
	if not ResourceLoader.exists(CELL_MUSIC):
		return
	var stream := load(CELL_MUSIC) as AudioStreamOggVorbis
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamOggVorbis
	stream.loop = false
	if _cell_music:
		_cell_music.queue_free()
	_cell_music = AudioStreamPlayer.new()
	_cell_music.name = "CellLoweringMusic"
	_cell_music.stream = stream
	_cell_music.volume_db = CELL_MUSIC_DB
	add_child(_cell_music)
	_cell_music.play()
	_cell_music_fade = -1.0


## Whether it is playing (and not on its way out).
func cell_music_on() -> bool:
	return _cell_music != null and _cell_music.playing and _cell_music_fade < 0.0


func _tick_cell_music(delta: float) -> void:
	if _cell_music == null or _cell_music_fade < 0.0:
		return
	_cell_music_fade += delta
	var amount := clampf(_cell_music_fade / CELL_MUSIC_FADE_OUT, 0.0, 1.0)
	_cell_music.volume_db = lerpf(CELL_MUSIC_DB, -60.0, amount)
	if amount >= 1.0:
		_cell_music.stop()
		_cell_music.queue_free()
		_cell_music = null
		_cell_music_fade = -1.0


## Under music the crowd dips, it does not vanish: a live room is not turned
## down for a song. The owner, 2 Nov: the crowd "drown[s] out the entrance
## music. Make the entrance music louder." Measured, the crowd loops sat 6-9 dB
## over the songs; the songs come up (StageVideo.music_db) and the loops dip
## 8 dB under an entrance song or the winner's theme.
const THEME_DUCK_DB := -8.0
## The roar and the heats dip less: the pop as the music hits stays a pop.
const MUSIC_DUCK_REACTIONS := 0.5
var _theme: AudioStreamPlayer
var _dynamite_theme: AudioStreamPlayer
var _opening_theme_elapsed := 0.0
var _opening_theme_fade_out := false
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
var _commentary_event_last_queued := {}
var _commentary_queue: Array[String] = []
var _commentary_delay := -1.0
var _commentary_clock := 0.0
var _last_repeatable_commentary_at := -INF
var _enda_easter_egg_selected := false
var _enda_easter_egg_used := false
var _sneaky_heel_easter_egg_selected := false
var _sneaky_heel_easter_egg_used := false
var _chaos_activity := 0.0
## Wrestlers already called out for a bloody match ("Look at the blood!").
var _blood_called := {}
var _enda_easter_egg_waiting := false
var _enda_cutaway_hold := 0.0
var _enda_down_candidate: WrestlerController
var _enda_down_seconds := 0.0
var _sign_fans: SignFans
var _match_camera: MatchCamera


func _ready() -> void:
	sfx = SfxPool.new()
	sfx.name = "Sfx"
	add_child(sfx)
	add_to_group(WeaponActor.LISTENERS)
	add_to_group(LISTENERS)
	chants = CrowdChants.new()
	chants.name = "Chants"
	add_child(chants)
	_bed = sfx.make_loop("crowd_bed")
	_swell = sfx.make_loop("crowd_swell")
	_boo_loop = sfx.make_loop("crowd_boo")
	_cheer_loop = sfx.make_loop("crowd_cheer")
	_roar = sfx.make_loop("crowd_roar")
	_bed.volume_db = BED_DB
	# Under the ring announcer when he speaks (RingAnnouncer.DUCK_DB).
	for p: AudioStreamPlayer in [_bed, _swell, _boo_loop, _cheer_loop, _roar]:
		p.bus = RingAnnouncer.under_bus()
	# Out of step from the first frame: each layer starts somewhere else in
	# its own loop (deterministic -- SfxPool's seeded generator, not the match's).
	for p: AudioStreamPlayer in [_bed, _swell, _boo_loop, _cheer_loop, _roar]:
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
	_sneaky_heel_easter_egg_selected = sneaky_heel_easter_egg_for_seed(match_seed)
	# Commentary choices are presentation-only, but a seeded stream keeps
	# replayed broadcasts consistent while still allowing alternate takes.
	_commentary_rng.seed = match_seed * 32771 + 4619
	chants.configure(RingAnnouncer.under_bus(), match_seed)
	if cody_is_in_match(wrestlers) and ResourceLoader.exists(CODY_CROWD_CHANT):
		chants.add_chant("cody", load(CODY_CROWD_CHANT) as AudioStream)
	if is_in_match(wrestlers, "roman"):
		for id: String in ROMAN_CROWD_CHANTS:
			if ResourceLoader.exists(ROMAN_CROWD_CHANTS[id]):
				chants.add_chant(id, load(ROMAN_CROWD_CHANTS[id]) as AudioStream)
	if ResourceLoader.exists(THIS_IS_AWESOME_CHANT):
		chants.add_chant("this_is_awesome", load(THIS_IS_AWESOME_CHANT) as AudioStream,
				THIS_IS_AWESOME_FROM)
	for w: WrestlerController in wrestlers:
		w.move_landed.connect(_on_move_landed)
		w.weapon_taken.connect(_on_weapon_taken)
		w.fsm.state_changed.connect(_on_wrestler_state_changed.bind(w))
		w.reversed.connect(func(_r, _s, _m): sfx.play("whoosh", -6.0))
		w.taunted.connect(_on_wrestler_taunted)
		w.fired_up.connect(_on_wrestler_fired_up)
		w.set_piece_landed.connect(_on_set_piece_landed)
		w.smashed_into_screen.connect(func(_who: WrestlerController) -> void:
			# the panel going: glass, the cabinet's metal, the hall
			sfx.play_any("hit_glass", hit_level("hit_glass", 3.0))
			sfx.play_any("hit_metal", hit_level("hit_metal", 0.0))
			sfx.play("pyro_bang", -12.0, 1.4)
			sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + 0.0)
			_register_chaos_activity(3.0))
		w.hit_the_cage.connect(func(_who: WrestlerController, strength: float) -> void:
			# the steel: the panel's crash and the chain link ringing
			sfx.play_any("hit_metal", clampf(-4.0 + strength * 3.0, -4.0, 3.0))
			sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB - 2.0 + strength)
			_register_chaos_activity(1.5 * strength))
		w.through_desk.connect(func(_who: WrestlerController) -> void:
			# the desk going: the boards, the monitors' glass and the steel
			# (desk_crash_0, made for it). The crowd's pop is set_piece_landed's.
			# desk_break: the worktop and panels caving, the monitors going.
			sfx.play_any("desk_break", 4.0)
			sfx.play_any("desk_crash", 0.0))
		var fire := w.find_child("ManFire", false, false) as ManFire
		if fire:
			fire.ignited.connect(_on_man_ignited)
			fire.extinguished.connect(_on_man_extinguished)
		_cooldown[w] = 0.0
		_falls[w] = []
	referee.match_won.connect(_on_match_won)


static func is_in_match(wrestlers: Array, style: String) -> bool:
	return wrestlers.any(func(w: Variant) -> bool:
		return w is WrestlerController and (w as WrestlerController).entrance_style == style)


static func cody_is_in_match(wrestlers: Array) -> bool:
	return wrestlers.any(func(w: Variant) -> bool:
		return w is WrestlerController and (w as WrestlerController).entrance_style == "cody")


## The entrances' cues (EntranceDirector.cue): the pyro, and the crowd as a
## man's music hits.
func follow(director: EntranceDirector) -> void:
	_director = director
	director.cue.connect(_on_cue)


## Whether an entrance song is playing on the wall.
func _entrance_music_on() -> bool:
	if _director == null or not is_instance_valid(_director._wall):
		return false
	return _director._wall.is_music_playing()


func share_voice_lane(announcer: RingAnnouncer) -> void:
	_voice_lane = announcer


## The sign gag is scheduled once in every match; its lull trigger, rather than
## a random match lottery, decides the exact moment it appears.
static func enda_easter_egg_for_seed(_match_seed: int) -> bool:
	return true


## Lines that belong to one man's entrance, by entrance style. Queued
## behind Justin's call, they wait in the voice lane; if the next man is
## already walking out by then (Kenny walking first: Justin's intro and his
## 22.7 s call fill the lane past the end of his entrance), they are dropped
## rather than played over the other man's.
const ENTRANCE_LINES := {"kenny": ["tony_kenny_focus", "excalibur_kenny_resume"]}


static func commentator_for_event(event: String) -> String:
	if event.begins_with("tony_") or event in [
			"gunshot", "cody_return", "roman_record", "roman_spear", "enda_easter_egg"]:
		return "tony"
	if event.begins_with("excalibur_"):
		return "excalibur"
	return ""


## Separate seeded draw so this gag does not track the sign cutaway's selection.
static func sneaky_heel_easter_egg_for_seed(match_seed: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 130363 + 2753
	return rng.randi_range(0, 2) == 0


## Excalibur signs off only after the complete post-match broadcast package.
func follow_post_match(post_match: PostMatch) -> void:
	post_match.finished.connect(_on_post_match_finished)


func _on_post_match_finished() -> void:
	_queue_commentary("tony_what_a_night")
	_queue_commentary("excalibur_signoff")


## The opening bell, whether after the entrances or on tick one.
func opening_bell() -> void:
	sfx.play("bell_start", -2.0, MATCH_BELL_PITCH_SCALE)
	if _cell_music and _cell_music.playing and _cell_music_fade < 0.0:
		_cell_music_fade = 0.0
	chants.bell()


func _on_cue(what: String) -> void:
	if what.begins_with("entrance_"):
		var style := what.trim_prefix("entrance_")
		for other: String in ENTRANCE_LINES:
			if other != style:
				for line: String in ENTRANCE_LINES[other]:
					_commentary_queue.erase(line)
	var commentary_event := commentary_event_for_cue(what)
	if commentary_event != "":
		_queue_commentary(commentary_event)
	if what == "broadcast_open":
		# Tony follows Excalibur's show-opening call in the same voice lane.
		_queue_commentary("tony_welcome")
		_start_dynamite_opening()
		if _crowd:
			_crowd.pop(1.0)
		sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -1.0)
	if what == "excalibur_crowd":
		# Tony answers Excalibur's crowd read before either entrance begins.
		_queue_commentary("tony_crowd_up")
		if _crowd:
			_crowd.pop(1.0)
		sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -3.0)
	if what == "announce_intro":
		# Keep the live-room bed swelling beneath the long welcome exchange.
		if _crowd:
			_crowd.pop(0.9)
		sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -3.0)
	if what == "cody_appear":
		# Excalibur answers Tony's Cody return call during Cody's entrance.
		_queue_commentary("excalibur_cody_career")
	if what == "called_kenny":
		# Excalibur answers Tony's line on Kenny, which answers Justin's call.
		_queue_commentary("excalibur_kenny_resume")
	match what:
		"cell_lower":
			_start_cell_music()
		"cell_padlock":
			# The chain round the door and the lock snapping shut.
			sfx.play_any("hit_metal", -9.0, 0.15)
		"cell_landed":
			# The steel hitting the floor: the panels' crash, a low thump
			# under it, and the room going up.
			sfx.play_any("hit_metal", 3.0)
			sfx.play("pyro_bang", -10.0, 0.7)
			sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -2.0)
		"pyro_opening":
			# The cold open's show, sound on its own timings (EntrancePyro.
			# _opening_show): the flame chase roaring, a launch and a burst for
			# each rocket wave, and the concussion's hit.
			_schedule_opening_pyro()
		"pyro_stage":
			sfx.play("pyro_boom", -1.0 + ENTRANCE_PYRO_BOOST_DB)
		"pyro_over_ring":
			# Comet jets off the post tops: the launch roars, the jets crack.
			_schedule_pyro(comet_sounds(EntrancePyro.cody_ring_plan()))
		"pyro_roman", "pyro_kenny":
			# Flame units: the roar of the fire under the boom.
			sfx.play("pyro_boom", -2.0 + ENTRANCE_PYRO_BOOST_DB)
			sfx.play("whoosh", -4.0 + ENTRANCE_PYRO_BOOST_DB)
		"pyro_cody_hit":
			# The WHOA's comet chase: a whoosh on every wave, the bang under
			# the first.
			sfx.play("pyro_bang", -4.0 + ENTRANCE_PYRO_BOOST_DB)
			_schedule_pyro(comet_sounds(EntrancePyro.cody_whoa_plan()))
		"pyro_cody_punch":
			sfx.play("pyro_bang", -2.0 + ENTRANCE_PYRO_BOOST_DB)
			sfx.play("pyro_boom", -8.0 + ENTRANCE_PYRO_BOOST_DB)
			sfx.play("whoosh", -2.0 + ENTRANCE_PYRO_BOOST_DB)
		"strobe":
			sfx.play("pyro_bang", -6.0)
		"tron_on":
			_fade_dynamite_opening()
			# The music hits: the building goes up around the entrance.
			sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -2.0)
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
	# By what lands (the owner, 19 Oct: each strike should sound like what it
	# is): an open hand slaps, a boot thuds, a forearm or an arm across the
	# chest is heavier than a fist.
	var file := move.resource_path.get_file().get_basename()
	if file.contains("chop"):
		return "hit_chop"
	if file.contains("kick") or file.contains("stomp") or file.contains("knee"):
		return "hit_kick"
	if file.contains("elbow") or file.contains("forearm") \
			or file.contains("clothesline") or file.contains("lariat"):
		return "hit_forearm"
	if file.begins_with("strike_") or file.begins_with("ground_") or file.contains("punch"):
		return "hit_punch"
	return ""


## A hand or an arm landing, rather than a boot or a weapon.
static func is_hand_strike(sound: String) -> bool:
	return sound in ["hit_punch", "hit_chop", "hit_forearm"]


static func hit_volume(move: MoveDef) -> float:
	var total := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	var t := clampf((total - HIT_DAMAGE_QUIET) / (HIT_DAMAGE_LOUD - HIT_DAMAGE_QUIET), 0.0, 1.0)
	return lerpf(-9.0, 0.0, t)


## The level `sound` plays at when the mix asks for `db`: steel and glass get
## their trim (HIT_TRIM_DB), but never past +3 dB over the file -- a cue that
## already asks for that much is left where it is.
static func hit_level(sound: String, db: float) -> float:
	var trim := float(HIT_TRIM_DB.get(sound, 0.0))
	return db if trim == 0.0 else minf(db + trim, maxf(db, trim))


## A gun's muzzle flash is the broadcast cue; other flashes (if added later)
## must not inherit this line.
static func commentary_event_for_weapon(weapon_id: StringName, event: String) -> String:
	return "gunshot" if weapon_id == &"handgun" and event == "flash" else ""


static func commentary_event_for_weapon_ready(weapon_id: StringName) -> String:
	var weapon := WeaponCatalog.by_id(weapon_id)
	if weapon == null:
		return ""
	if weapon_id == &"barbed_wire_chair":
		return "tony_barbed_wire_chair"
	if weapon_id == &"bed_of_nails":
		return "excalibur_bed_of_nails"
	var exceptional_risk := weapon_id in [
		&"steel_chair", &"baseball_bat", &"ladder", &"light_tubes", &"barbed_wire_chair",
		&"barbed_wire_bat", &"bed_of_nails", &"barbed_wire_board", &"knife", &"sword",
		&"handgun", &"rpg",
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
	sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -9.0)
	var event := commentary_event_for_heel_pose(who.entrance_style)
	if event != "":
		# A heel lording it over a man he has already put down: Tony's snarky
		# "I'm so sick of this guy." Otherwise the usual heel call.
		_queue_commentary("tony_sick_of_this_guy" if _anyone_down_but(who) else event)
		_queue_sneaky_heel_easter_egg(who.entrance_style)


## Whether anyone other than `who` is down on the mat.
func _anyone_down_but(who: WrestlerController) -> bool:
	for other: WrestlerController in _wrestlers:
		if other != who and is_instance_valid(other) \
				and other.fsm.current_state == WrestlerFSM.State.DOWN:
			return true
	return false


func _queue_sneaky_heel_easter_egg(entrance_style: String) -> void:
	if entrance_style != "roman" or not _sneaky_heel_easter_egg_selected \
			or _sneaky_heel_easter_egg_used:
		return
	_sneaky_heel_easter_egg_used = true
	_queue_commentary("tony_sneaky_heel_easter_egg")


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
		"faceoff_tension":
			return "tony_tension"
		"called_kenny":
			return "tony_kenny_focus"
	return ""


static func commentary_event_for_state(state: int) -> String:
	return "tony_submission" if state == WrestlerFSM.State.SUBMISSION_ATTACKER else ""


static func commentary_events_for_kickout(count: int, match_over: bool,
		late_match := false) -> Array[String]:
	if count >= 2 and not match_over:
		if late_match:
			# Late in the match, a kick-out at two is a "how did he kick out
			# of that?" moment: Excalibur's Unbelievable plus Tony's disbelief.
			return ["excalibur_unbelievable", "tony_dramatic_kickout"]
		return ["excalibur_two_count", "tony_love_this_business"]
	return []


## "The American Nightmare is bleeding profusely, refusing to stay down" --
## the owner-supplied worried and reserved Tony line, for a bloodied Cody
## kicking out at two. Only on a bleeding Cody, not on any kickout.
static func commentary_event_for_cody_kickout(defender: WrestlerController,
		count: int) -> String:
	if count < 2 or defender == null:
		return ""
	if Persona.of(defender.display_name) != Persona.Kind.FACE:
		return ""
	var blood := defender.find_child("Blood", false, false)
	if blood == null or blood.head <= 0.5:
		return ""
	return "tony_american_nightmare_blood"


static func commentary_event_for_spectacular_spot(move_pop: float, match_time: float) -> String:
	return "excalibur_unbelievable" if move_pop >= UNBELIEVABLE_SPECTACULAR_POP \
			and match_time >= UNBELIEVABLE_LATE_MATCH_AFTER else ""


## Cody's own hold gets Excalibur's line in place of Tony's generic
## submission call (the owner, 13 Nov): ten reverent seconds that Tony's
## "locked in tight" would otherwise talk over.
static func commentary_event_for_submission(entrance_style: String, move: MoveDef) -> String:
	if entrance_style == "cody" and move != null \
			and move.resource_path.get_file().get_basename() == "submission_figure_four":
		return "excalibur_cody_figure_four"
	return ""


## A move landing on a man from behind (a blindside): the attacker stands
## behind the defender's facing. Narration only -- it writes no match state.
static func _move_lands_from_behind(attacker: WrestlerController,
		defender: WrestlerController) -> bool:
	var to_attacker := attacker.global_position - defender.global_position
	to_attacker.y = 0.0
	if to_attacker.length() < 0.3:
		return false
	var forward := -defender.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return false
	return forward.normalized().dot(to_attacker.normalized()) < -0.35


func _on_wrestler_state_changed(_previous: int, current: int,
		who: WrestlerController = null) -> void:
	var commentary_event := commentary_event_for_state(current)
	if commentary_event != "" and who != null:
		var own := commentary_event_for_submission(who.entrance_style, who.submission_move)
		if own != "":
			commentary_event = own
	if commentary_event != "":
		_queue_commentary(commentary_event)


static func commentary_event_for_landed_move(entrance_style: String, move_id: String) -> String:
	if entrance_style != "roman":
		return ""
	if move_id == "signature_superman_punch":
		return "excalibur_superman_punch"
	return "roman_spear" if move_id == "finisher_spear" else "roman_record"


## Excalibur's strike calls are for committed punches and body kicks, not light
## jabs or incidental leg strikes.
static func commentary_event_for_landed_strike(move: MoveDef) -> String:
	if move == null:
		return ""
	var move_id := move.resource_path.get_file().get_basename()
	if not move_id.begins_with("strike_"):
		return ""
	if is_hand_strike(hit_sound(move)):
		var damage := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
		return "excalibur_strikes" if damage >= 8.0 else ""
	if hit_sound(move) == "hit_kick" and move.damage_torso >= 6.0:
		return "excalibur_body_kicks"
	return ""


func _on_wrestler_fired_up(who: Variant) -> void:
	_heat(who, 0.7)
	sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -6.0)
	_queue_commentary("excalibur_comeback")
	_queue_commentary("tony_momentum_shift")


## Most story and setup cues are one-shot. Move calls and "Unbelievable" can
## return when another fitting moment arrives, with per-line and shared gaps
## to keep them from sounding like a loop.
func _queue_commentary(event: String) -> void:
	if not COMMENTARY_CLIPS.has(event):
		return
	var clips: Array = COMMENTARY_CLIPS[event]
	if clips.is_empty():
		return
	if _commentary_queue.has(event):
		return
	var repeat_cooldown := float(COMMENTARY_REPEAT_COOLDOWNS.get(event, 0.0))
	if repeat_cooldown <= 0.0 and _commentary_events_played.has(event):
		return
	if repeat_cooldown > 0.0:
		var last_queued := float(_commentary_event_last_queued.get(event, -INF))
		if _commentary_clock - last_queued < repeat_cooldown \
				or _commentary_clock - _last_repeatable_commentary_at < COMMENTARY_REPEAT_MIN_GAP:
			return
	if clips.all(func(path: String) -> bool: return not ResourceLoader.exists(path)):
		return
	# Mark on enqueue so duplicate triggers cannot stack while a line waits.
	_commentary_events_played[event] = true
	_commentary_event_last_queued[event] = _commentary_clock
	if repeat_cooldown > 0.0:
		_last_repeatable_commentary_at = _commentary_clock
	if event in COMMENTARY_LIVE_CALLS:
		_commentary_queue.push_front(event)
	else:
		_commentary_queue.append(event)


## Excalibur on a man going up, and on Aubrey putting him out. Once a match
## each: a second "He's on fire!" would sound like a loop.
func _on_man_ignited(_who: WrestlerController) -> void:
	_queue_commentary("excalibur_on_fire")


func _on_man_extinguished(_who: WrestlerController) -> void:
	_queue_commentary("excalibur_thank_aubrey")


## The call for a landed Cody Cutter, standing or off the springboard.
static func commentary_event_for_cody_cutter(entrance_style: String, move_id: String) -> String:
	return "excalibur_cody_cutter" if entrance_style == "cody" \
			and move_id in CODY_CUTTER_MOVES else ""


## Which call a dive landing gets (DiveSpot): the tope suicida, or the
## springboard Cody Cutter.
static func commentary_event_for_dive(entrance_style: String, move_path: String) -> String:
	var move_id := move_path.get_file().get_basename()
	if move_id == "dive_tope_suicida":
		return "excalibur_tope_suicida"
	return commentary_event_for_cody_cutter(entrance_style, move_id)


## DiveSpot's contact ticks (it lands its dives itself, not through
## move_landed).
func on_dive_landed(attacker: WrestlerController, move_path: String) -> void:
	if attacker == null:
		return
	var event := commentary_event_for_dive(attacker.entrance_style, move_path)
	if event != "":
		_queue_commentary(event)


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
	return lerpf(PHASE_START, PHASE_FLOOR_MAX, smoothstep(0.0, 1.0, clock / PHASE_FULL))


## Each loop's target level for an intensity (0-1), by layer name.
static func bed_levels(i: float) -> Dictionary:
	i = clampf(i, 0.0, 1.0)
	return {
		"bed": lerpf(BED_DB, BED_EXCITED_DB, i) + CROWD_MIX_GAIN_DB,
		"swell": lerpf(SWELL_DB[0], SWELL_DB[1], i * i) + CROWD_MIX_GAIN_DB,
	}


## A heat (boos or a cheer, 0-1) as a level: off below a whisper.
static func heat_db(heat: float) -> float:
	if heat < 0.02:
		return -80.0
	return lerpf(HEAT_OFF_DB, HEAT_ON_DB, clampf(heat, 0.0, 1.0)) \
			+ CROWD_MIX_GAIN_DB


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


func _on_move_landed(attacker, defender, move: MoveDef) -> void:
	_heat(attacker, 0.12 + 0.5 * CrowdReaction.move_pop(move))
	var sound := hit_sound(move)
	var hit_db := hit_level(sound, hit_volume(move))
	if sound != "" and not sfx.play_any(sound, hit_db):
		sfx.play(sound, hit_db)      # a one-off: the bell, the whoosh
	var pop := CrowdReaction.move_pop(move)
	if pop >= POP_MOVE:
		sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + lerpf(-8.0, -2.0, clampf((pop - POP_MOVE) / (1.0 - POP_MOVE), 0.0, 1.0)))
	if attacker is WrestlerController:
		var move_id := move.resource_path.get_file().get_basename()
		if WeaponCatalog.of_move(move) != null:
			_register_chaos_activity(1.0)
		var commentary_event := commentary_event_for_roman_heel_attack(
				attacker.entrance_style, move)
		if commentary_event != "":
			_queue_commentary(commentary_event)
			if commentary_event == "tony_roman_heel":
				_queue_sneaky_heel_easter_egg(attacker.entrance_style)
		elif commentary_event_for_cody_cutter(attacker.entrance_style, move_id) != "":
			_queue_commentary(commentary_event_for_cody_cutter(attacker.entrance_style, move_id))
		elif move_id in ["signature_superman_punch", "finisher_spear"]:
			commentary_event = commentary_event_for_landed_move(attacker.entrance_style, move_id)
			if commentary_event != "":
				_queue_commentary(commentary_event)
		else:
			commentary_event = commentary_event_for_spectacular_spot(pop, chants.match_time())
			if commentary_event != "":
				_queue_commentary(commentary_event)
				# Tony, caught off guard and searching for words, to Excalibur
				# after an unbelievable spot (Excalibur's reaction leads).
				_queue_commentary("tony_speechless")
			else:
				commentary_event = commentary_event_for_landed_strike(move)
				if commentary_event != "":
					_queue_commentary(commentary_event)
				else:
					commentary_event = commentary_event_for_landed_move(attacker.entrance_style, move_id)
					if commentary_event != "":
						_queue_commentary(commentary_event)
		# A move landed on a man from behind: "Watch out! Behind you!"
		if defender is WrestlerController and _move_lands_from_behind(attacker, defender):
			_queue_commentary("tony_watch_out_behind")


## A weapon going off or breaking (WeaponActor.LISTENERS).
func on_weapon_event(weapon: WeaponActor, event: String) -> void:
	match event:
		"flash":
			sfx.play("pyro_bang", GUNSHOT_DB)
			sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + -4.0)
			var commentary_event := commentary_event_for_weapon(weapon.def.id, event)
			if commentary_event != "":
				_queue_commentary(commentary_event)
			_register_chaos_activity(3.0)
		"cloud":
			sfx.play("whoosh", -2.0, 0.7)
		"breath":
			# the fuel going up out of his mouth: a roar of flame, and the hall
			sfx.play("whoosh", 0.0, 0.5)
			sfx.play("pyro_boom", -8.0, 1.5)
			sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + -1.0)
			_register_chaos_activity(2.5)
		"rocket":
			sfx.play("whoosh", ROCKET_LAUNCH_DB, 0.8)
			sfx.play("pyro_bang", ROCKET_IGNITION_DB, 0.7)
		"blast":
			sfx.play("pyro_boom", ROCKET_BLAST_DB)
			sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + -2.0)
			_register_chaos_activity(3.0)
		"set_up":
			if weapon.def.id == &"table":
				chants.table_set_up()
		"ignite":
			# the table going up: the whoosh of the fuel catching, and the hall
			sfx.play("whoosh", -1.0, 0.6)
			sfx.play("pyro_boom", -10.0, 1.3)
			sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + -2.0)
			_register_chaos_activity(2.0)
		"broke":
			if weapon.def.id == &"table":
				# A thunderous smash, not a crack (the owner, 3 Nov: "a very
				# loud thunderous smash noise of the table"): the boards going,
				# the heavier crash of the desk under them, and a low boom for
				# the body through it.
				# table_break: the board cracking through, the splinters,
				# the legs going and the man landing in it, as one loud file
				# (tools/audio/build_break_sfx.py; the owner, 9 Nov: "make a
				# loud crash sound").
				sfx.play_any("table_break", 4.0)
				sfx.play("pyro_boom", -4.0, 0.55)
				sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + 1.0)
			elif weapon.def.id == &"glass_pane":
				# the sheet going: glass, over the thud of him and the frame
				# glass_break: the sheet bursting and the shards raining down
				sfx.play_any("glass_break", 3.0)
				sfx.play_any("hit_glass", hit_level("hit_glass", -2.0))
				sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + 0.0)
			elif not sfx.play_any(weapon.def.sound, hit_level(weapon.def.sound, -1.0)):
				sfx.play(weapon.def.sound, hit_level(weapon.def.sound, -1.0))


## Through a table: the crowd. (The crack itself is the table's "broke".)
func _on_set_piece_landed(who: WrestlerController, weapon: WeaponActor, broke: bool) -> void:
	var by := who.opponent
	_heat(by, 0.8 if broke else 0.4)
	sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -1.0 if broke else -5.0)
	sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + -2.0 if broke else -4.0)
	if not broke and weapon != null:
		sfx.play_any(weapon.def.sound, hit_level(weapon.def.sound, -3.0))
	_register_chaos_activity(2.0 if broke else 0.5)


## "Look at the blood! Look at the intensity!" -- Tony's call once a man's
## blood has come up. Fires once per wrestler per match, so a gusher is a
## broadcast moment, not a running tally.
func _hear_blood(w: WrestlerController) -> void:
	if _over or _blood_called.has(w):
		return
	var blood := w.find_child("Blood", false, false) as Blood
	if blood == null:
		return
	if maxf(blood.shown_head, blood.shown_back) < BLOOD_CALL_AT:
		return
	_blood_called[w] = true
	_queue_commentary("tony_blood_intensity")


func _register_chaos_activity(amount: float) -> void:
	_chaos_activity = minf(_chaos_activity + amount, CHAOS_COMMENTARY_THRESHOLD * 2.0)
	if _chaos_activity < CHAOS_COMMENTARY_THRESHOLD:
		return
	# Chaos: Excalibur calls for order restored, or Tony's awed "Look at the
	# carnage!" -- alternating between the two broadcast reactions.
	_queue_commentary("tony_carnage" if _commentary_rng.randi_range(0, 1) == 0 else "excalibur_restore_order")
	_chaos_activity = 0.0


func _on_match_won(winner: Variant, method: String) -> void:
	_over = true
	chants.match_over(favor_of((winner as WrestlerController).display_name) if winner is WrestlerController else 0.0)
	# The three lands on the tick the match ends, before _process hears the
	# count: slap it here so the hand comes down before the bell, not after.
	if method == "pinfall" and _count_heard < 3:
		_count_heard = 3
		sfx.play_any("count_slap", -1.0)
		chants.count(3, sfx)
	sfx.play("bell_end", -1.0, MATCH_BELL_PITCH_SCALE)
	sfx.play("crowd_finish", CROWD_REACTION_GAIN_DB)
	# "He got him! He got him! One, two, three!" -- the pinfall-win call, ahead
	# of Excalibur's finish so the count is heard as the hand comes down.
	if method == "pinfall":
		_queue_commentary("tony_pinfall_win")
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


## The match opens on the owner-supplied Dynamite theme, as in the show
## broadcast. It sits below the commentary and cross-fades into the first
## wrestler's entrance music when the tron comes up.
func _start_dynamite_opening() -> void:
	if not ResourceLoader.exists(DYNAMITE_OPENING_THEME):
		return
	if _dynamite_theme:
		_dynamite_theme.stop()
		_dynamite_theme.queue_free()
	_dynamite_theme = AudioStreamPlayer.new()
	_dynamite_theme.name = "DynamiteOpeningTheme"
	_dynamite_theme.stream = load(DYNAMITE_OPENING_THEME) as AudioStream
	_dynamite_theme.volume_db = -60.0
	add_child(_dynamite_theme)
	_opening_theme_elapsed = 0.0
	_opening_theme_fade_out = false
	_dynamite_theme.play()


func _fade_dynamite_opening() -> void:
	if _dynamite_theme and _dynamite_theme.playing:
		_opening_theme_elapsed = 0.0
		_opening_theme_fade_out = true


func _tick_opening_theme(delta: float) -> void:
	if not _dynamite_theme or not _dynamite_theme.playing:
		return
	_opening_theme_elapsed += delta
	if _opening_theme_fade_out:
		var amount := clampf(_opening_theme_elapsed / DYNAMITE_OPENING_FADE_OUT, 0.0, 1.0)
		_dynamite_theme.volume_db = lerpf(DYNAMITE_OPENING_THEME_DB, -60.0, amount)
		if amount >= 1.0:
			_dynamite_theme.stop()
	else:
		var amount := clampf(_opening_theme_elapsed / DYNAMITE_OPENING_FADE_IN, 0.0, 1.0)
		_dynamite_theme.volume_db = lerpf(-60.0, DYNAMITE_OPENING_THEME_DB, amount)


func _process(delta: float) -> void:
	_commentary_clock += delta
	_tick_opening_theme(delta)
	_tick_cell_music(delta)
	_chaos_activity = maxf(0.0, _chaos_activity - delta * CHAOS_COMMENTARY_DECAY_PER_SECOND)
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
				if stream != null:
					var speaker := commentator_for_event(event)
					if not speaker.is_empty():
						commentary_started.emit(speaker, stream.get_length())
						for actor: Node in get_tree().get_nodes_in_group("commentators"):
							if actor.has_method("commentary_started"):
								actor.call("commentary_started", speaker, stream.get_length())
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
	var duck_to := THEME_DUCK_DB if _entrance_music_on() or cell_music_on() else 0.0
	if _theme:
		_theme_fade = minf(_theme_fade + delta / THEME_FADE_IN, 1.0)
		_theme.volume_db = lerpf(-40.0, THEME_DB, _theme_fade * _theme_fade)
		duck_to = minf(duck_to, THEME_DUCK_DB * _theme_fade)
	_duck = lerpf(_duck, duck_to, 1.0 - exp(-delta * 2.0))
	_slew(_bed, levels["bed"] + _duck, delta)
	_slew(_swell, levels["swell"] + _duck, delta)
	_slew(_boo_loop, heat_db(boo) + _duck * MUSIC_DUCK_REACTIONS, delta)
	_slew(_cheer_loop, heat_db(cheer) + _duck * MUSIC_DUCK_REACTIONS, delta)
	if _roar:
		var level := clampf((excitement - ROAR_FLOOR) / (1.0 - ROAR_FLOOR), 0.0, 1.0)
		_roar.volume_db = ROAR_MAX_DB + CROWD_MIX_GAIN_DB + _duck * MUSIC_DUCK_REACTIONS \
				+ linear_to_db(maxf(pow(level, 1.5), 0.0001))
	_hear_the_count()
	chants.tick(delta, excitement)
	for w: WrestlerController in _wrestlers:
		if is_instance_valid(w):
			_hear_bumps(w, delta)
			_hear_blood(w)
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
	_enda_easter_egg_waiting = true


func _cancel_enda_easter_egg() -> void:
	if _enda_easter_egg_waiting and _sign_fans != null and is_instance_valid(_sign_fans):
		_sign_fans.cancel_enda_easter_egg()
	_enda_easter_egg_waiting = false


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
		sfx.play_any("crowd_ooh", CROWD_REACTION_GAIN_DB + -3.0)
		sfx.play_any("crowd_pop", CROWD_REACTION_GAIN_DB + -4.0)
	var events := commentary_events_for_kickout(_count_heard, _over,
			chants.match_time() >= UNBELIEVABLE_LATE_MATCH_AFTER)
	if not pinning and _was_pinning:
		for event: String in events:
			if event == "excalibur_unbelievable":
				_queue_commentary(event)
			else:
				_queue_commentary(event)
		# A bleeding Cody who will not stay down: the worried and reserved Tony
		# line, only when the man kicking out at two is a bleeding Cody.
		var cody_event := commentary_event_for_cody_kickout(_referee._pin_defender, _count_heard)
		if cody_event != "":
			_queue_commentary(cody_event)
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


## [seconds, sound, gain dB] for the cold open's pyro, off EntrancePyro's own
## timings so picture and sound cannot drift apart.
static func opening_pyro_sounds() -> Array:
	var out: Array = []
	for k in range(0, EntrancePyro.OPENING_FLAME_STEPS, 2):
		out.append([k * EntrancePyro.OPENING_FLAME_GAP, "whoosh", -7.0])
	for t: float in EntrancePyro.OPENING_ROCKET_AT:
		out.append([t, "pyro_bang", -3.0])
		out.append([t + EntrancePyro.OPENING_ROCKET_FLIGHT, "pyro_boom", -4.0])
	out.append([EntrancePyro.OPENING_CONCUSSION_AT, "pyro_boom", 1.0])
	out.append([EntrancePyro.OPENING_CONCUSSION_AT, "pyro_bang", 1.0])
	return out


## A comet plan's sound: one launch whoosh per wave (the jets within a wave
## go up together), [seconds, name, dB].
static func comet_sounds(plan: Array) -> Array:
	var out: Array = []
	var last := -1.0
	for c: Array in plan:
		var t := float(c[0])
		if last < 0.0 or t - last >= 0.25:
			out.append([t, "whoosh", -5.0])
			last = t
	return out


func _schedule_opening_pyro() -> void:
	_schedule_pyro(opening_pyro_sounds())


func _schedule_pyro(cues: Array) -> void:
	for cue: Array in cues:
		var name: String = cue[1]
		var gain: float = float(cue[2]) + ENTRANCE_PYRO_BOOST_DB
		get_tree().create_timer(float(cue[0])).timeout.connect(func() -> void:
			if is_instance_valid(sfx):
				sfx.play(name, gain))
