class_name WrestlerVoice
extends Node3D
## What a man says when he is hurt (the owner, 19 Oct: "pain noises" so a
## strike reads, and a man on fire screaming until he is put out).
##
## A grunt on a blow, a heavy grunt on a hard one, a groan when he hits the mat
## and a yell for the worst of it -- a blade, a wipeout, a signature or a
## finisher. Set alight (ManFire.ignited) he screams take after take, a breath
## between them, until he is put out (ManFire.extinguished): the scream fades
## and he ends on a groan.
##
## Presentation only: nothing in a match reads what he said. The takes are
## the CC0 voices tools/audio/build_sfx.py writes (grunt_light_*, grunt_heavy_*,
## groan_*, yell_*, burn_scream_*). Picks are seeded from the match seed and
## his name, so a replay says the same; never the global generator, which the
## match seed is drawn from.

## The shortest time between two things he says: any closer and a flurry of
## jabs is a stammer.
const MIN_GAP := 0.6
## A light blow is grunted at this often; the rest he takes in silence.
const LIGHT_CHANCE := 0.5
## Down on the mat: the groan comes as he lands, not as he starts to fall.
const DOWN_GROAN_DELAY := 0.55
## Seconds of breath between two screams.
const BURN_BREATH := 0.18
## The scream fades out over this when the fire is out.
const BURN_FADE := 0.3
## Level of each kind of voice, against the hits (SfxPool at 0 dB).
const LEVEL_DB := {"grunt_light": -6.0, "grunt_heavy": -3.0, "groan": -4.0, "yell": -1.0,
		"burn_scream": 0.0}
## So two men do not sound like one: Roman lower, Kenny a touch higher.
const PITCH := {"roman": 0.9, "cody": 1.0, "kenny": 1.05}
const DETUNE := 0.03
## Where his mouth is, over his feet.
const HEAD_HEIGHT := 1.7

## Each thing he says as it starts, for tests and probes.
signal said(family: String, sound: String)

var wrestler: WrestlerController
var screaming := false
var _player: AudioStreamPlayer3D
var _scream: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _seeded := false
var _since := INF
var _last := {}
var _groan_in := -1.0
var _breath := -1.0
var _fading := -1.0


## Hangs a voice on `w`, listening to his hits, his falls and his fire.
static func attach(w: WrestlerController, fire: ManFire = null) -> WrestlerVoice:
	var v := WrestlerVoice.new()
	v.name = "PainVoice"
	v.wrestler = w
	v.position = Vector3(0.0, HEAD_HEIGHT, 0.0)
	w.add_child(v)
	v._player = v._make_player("Say")
	v._scream = v._make_player("Scream")
	w.hurt.connect(v.hurt)
	w.knocked_down.connect(func(_who: WrestlerController) -> void: v._groan_in = DOWN_GROAN_DELAY)
	if fire:
		fire.ignited.connect(func(_who: WrestlerController) -> void: v.start_screaming())
		fire.extinguished.connect(func(_who: WrestlerController) -> void: v.stop_screaming())
	return v


func _make_player(n: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	# A ringside mic, not his own ears: full level across the ring, fading
	# only as far off as the hard camera.
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	p.unit_size = 10.0
	p.max_distance = 60.0
	add_child(p)
	return p


## Which kind of voice a hit draws: "" for none. `sell` is the tier he sells
## (WrestlerController.Sell), `move` what hit him. Light hits are only
## sometimes grunted; that chance is hurt()'s, not this.
static func family_for(sell: int, move: MoveDef) -> String:
	var weapon := WeaponCatalog.of_move(move) if move else null
	if weapon:
		match WeaponCatalog.impact_of(weapon):
			WeaponCatalog.Impact.BLADE, WeaponCatalog.Impact.WIPEOUT, WeaponCatalog.Impact.FATAL:
				return "yell"
			WeaponCatalog.Impact.ROCK, WeaponCatalog.Impact.DROP:
				return "grunt_heavy"
	if move and move.momentum_cost > 0.0:
		return "yell"
	match sell:
		WrestlerController.Sell.LIGHT:
			return "grunt_light"
		WrestlerController.Sell.MEDIUM:
			return "grunt_light" if weapon == null else "grunt_heavy"
		WrestlerController.Sell.HEAVY, WrestlerController.Sell.KNEE:
			return "grunt_heavy"
		WrestlerController.Sell.DOWN:
			return "groan"
	return ""


## He has just been hit (WrestlerController.hurt).
func hurt(sell: int, move: MoveDef) -> void:
	var family := family_for(sell, move)
	if family == "":
		return
	if family == "grunt_light" and sell == WrestlerController.Sell.LIGHT and _roll() > LIGHT_CHANCE:
		return
	say(family)


## Says one take of `family`, unless he spoke a moment ago or is screaming.
## Returns whether he did.
func say(family: String) -> bool:
	if screaming or _since < MIN_GAP:
		return false
	var sound := _pick(family)
	if sound == "":
		return false
	_play(_player, sound, family)
	return true


func start_screaming() -> void:
	if screaming:
		return
	screaming = true
	_fading = -1.0
	_groan_in = -1.0
	_player.stop()
	_next_scream()


## Put out: the scream fades and he ends on a groan.
func stop_screaming() -> void:
	if not screaming:
		return
	screaming = false
	_breath = -1.0
	_fading = BURN_FADE
	_since = INF
	_groan_in = BURN_FADE


func _process(delta: float) -> void:
	_since += delta
	if _groan_in >= 0.0:
		_groan_in -= delta
		if _groan_in < 0.0:
			say("groan")
	if screaming and not _scream.playing:
		if _breath < 0.0:
			_breath = BURN_BREATH
		_breath -= delta
		if _breath < 0.0:
			_next_scream()
	if _fading >= 0.0:
		_fading -= delta
		var level := float(LEVEL_DB["burn_scream"])
		_scream.volume_db = level + linear_to_db(maxf(_fading / BURN_FADE, 0.001))
		if _fading < 0.0:
			_scream.stop()


func _next_scream() -> void:
	_breath = -1.0
	var sound := _pick("burn_scream")
	if sound != "":
		_play(_scream, sound, "burn_scream")


func _play(p: AudioStreamPlayer3D, sound: String, family: String) -> void:
	p.stream = SfxPool.stream(sound)
	p.volume_db = float(LEVEL_DB.get(family, -4.0))
	p.pitch_scale = _pitch() + _rng.randf_range(-DETUNE, DETUNE)
	p.play()
	_since = 0.0
	said.emit(family, sound)


## A take of `family`, never the one he said last time.
func _pick(family: String) -> String:
	var n := SfxPool.family_size(family)
	if n == 0:
		return ""
	_seed()
	var i := _rng.randi_range(0, n - 1)
	if n > 1 and i == int(_last.get(family, -1)):
		i = (i + 1 + _rng.randi_range(0, n - 2)) % n
	_last[family] = i
	return "%s_%d" % [family, i]


func _roll() -> float:
	_seed()
	return _rng.randf()


func _seed() -> void:
	if _seeded:
		return
	_seeded = true
	_rng.seed = hash([wrestler.match_seed if wrestler else 0, String(wrestler.name) if wrestler else ""])


func _pitch() -> float:
	return float(PITCH.get(wrestler.entrance_style if wrestler else "", 1.0))
