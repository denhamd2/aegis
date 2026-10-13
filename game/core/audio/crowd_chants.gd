class_name CrowdChants
extends Node
## When the building chants, and what. MatchAudio tells it what happens --
## who is landing what, a near-fall, a table going up, the bell -- and it
## decides, from that and the room's excitement, whether a chant starts.
##
## A real crowd chants seldom and for a reason: a man fighting back, a
## near-fall in a long match, a table, a stall. So every chant waits for its
## reason, at most one plays at a time, the room rests MIN_GAP seconds after
## one, and the same chant waits SAME_GAP before it is heard again. A reason
## that cannot be served in REASON_LIFE seconds is dropped, not queued: a
## "This is awesome" a minute after the near-fall is a bug.
##
## The chants are built by tools/audio/build_chants.py. Presentation only:
## nothing a match reads comes from here, and its picks are from its own
## seeded generator, never the match's.

## Each chant as it starts, for tests and probes.
signal chanted(chant: String)

const MIN_GAP := 22.0
const SAME_GAP := 110.0
const REASON_LIFE := 4.0
## A man "has the match" at this many landed moves inside MOMENTUM_WINDOW.
const MOMENTUM_MOVES := 3
const MOMENTUM_WINDOW := 9.0
## A stall: the room this flat for this long, past the opening minute.
const STALL_EXCITEMENT := 0.12
const STALL_SECONDS := 32.0
const STALL_AFTER := 90.0
## A near-fall is worth "This is awesome" this far into a match; before it,
## "Holy cow" at most.
const AWESOME_AFTER := 240.0
## The bell: "You deserve it" for the face at once, "One more match" after a
## long one.
const DESERVE_DELAY := 3.0
const ONE_MORE_DELAY := 17.0
const ONE_MORE_AFTER := 420.0
const CHANT_DB := -3.0
const COUNT_DB := -4.0
## The sung WHOAs in Cody's entrance music, seconds from its start
## (EntranceDirector.CODY_WHOA_1 ...): the building sings them with him.
const CODY_WHOAS := [0.8, 3.6, 6.3, 22.5, 24.0, 43.5]
## His name once he is in the aisle, and Roman's people once his music hits.
const CODY_NAME_AT := 48.0
const ROMAN_OTC_AT := 52.0

var clock := 0.0
## Who is in the match: a chant for a man who is not there is never sung.
var cody_here := false
var roman_here := false
var sfx: SfxPool
var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _since_end := MIN_GAP          # seconds since the last chant finished
var _last := {}                    # chant -> clock when it last started
var _reasons := {}                 # chant -> clock the reason arose
var _moves := {}                   # favour (-1, 1) -> [clock, ...]
var _flat := 0.0
var _after_bell := -1.0
var _winner_favor := 0.0
var _entrance := ""
var _entrance_t := 0.0
var _entrance_done := {}


func _ready() -> void:
	_rng.seed = 0x0c0d7
	_player = AudioStreamPlayer.new()
	_player.name = "Chant"
	_player.bus = RingAnnouncer.under_bus()
	add_child(_player)


## The take of `chant` to play: one of chant_x_0, chant_x_1, ... or "".
func take_of(chant: String) -> String:
	var n := SfxPool.family_size(chant)
	if n == 0:
		return ""
	return "%s_%d" % [chant, _rng.randi_range(0, n - 1)]


func is_chanting() -> bool:
	return _player.playing


# --- what happened --------------------------------------------------------

## A move landed by a man the house is for (+1), against (-1), or neither.
func moved(favor: float, pop: float) -> void:
	if favor == 0.0:
		return
	var key := int(signf(favor))
	var list: Array = _moves.get(key, [])
	list.append(clock)
	while not list.is_empty() and clock - float(list[0]) > MOMENTUM_WINDOW:
		list.pop_front()
	_moves[key] = list
	if list.size() >= MOMENTUM_MOVES or pop >= 0.8:
		if key > 0:
			_reason(&"chant_cody" if _rng.randf() < 0.6 else &"chant_lets_go_cody")
		else:
			# The heel on top: half the house rallies the face, his own
			# people answer for him.
			_reason(&"chant_lets_go_cody" if _rng.randf() < 0.5 else &"chant_otc")
		list.clear()


## A man fired up on his comeback.
func fired_up(favor: float) -> void:
	if favor > 0.0:
		_reason(&"chant_cody")


## The cover broken after `count` (2 is a near-fall).
func kicked_out(count: int) -> void:
	if count < 2:
		return
	_reason(&"chant_this_is_awesome" if clock >= AWESOME_AFTER else &"chant_holy_cow")


## A table stood up for somebody.
func table_set_up() -> void:
	_reason(&"chant_tables")


## The referee's hand coming down: the building counts with him.
func count(n: int, sfx: SfxPool) -> void:
	if n >= 1 and n <= 3:
		sfx.play_any("crowd_count_%d" % n, COUNT_DB, 0.02)


## The bell, and who it was for.
func match_over(winner_favor: float) -> void:
	_after_bell = 0.0
	_winner_favor = winner_favor
	# Whatever was going stops for the bell; the room starts over.
	_reasons.clear()


## An entrance started (its music on the wall): "cody", "roman" or other.
func entrance(style: String) -> void:
	_entrance = style
	_entrance_t = 0.0
	_entrance_done.clear()


# --- deciding --------------------------------------------------------------

func _reason(chant: StringName) -> void:
	if not sung_here(String(chant)):
		return
	_reasons[chant] = clock


## Whether this match has the man `chant` is about (or it is about nobody).
func sung_here(chant: String) -> bool:
	if chant.contains("cody"):
		return cody_here
	if chant.contains("roman") or chant.contains("otc"):
		return roman_here
	return true


## What to chant now, of `reasons` (chant -> when it arose), or "" -- the
## whole rule, without the player, so it can be tested.
static func pick(reasons: Dictionary, last: Dictionary, now: float, since_end: float,
		chanting: bool) -> String:
	if chanting or since_end < MIN_GAP:
		return ""
	var best := ""
	var best_at := -INF
	for chant: StringName in reasons:
		var at: float = reasons[chant]
		if now - at > REASON_LIFE:
			continue
		if last.has(chant) and now - float(last[chant]) < SAME_GAP:
			continue
		if SfxPool.family_size(String(chant)) == 0:
			continue
		# The freshest reason wins: the crowd answers what just happened.
		if at > best_at:
			best = String(chant)
			best_at = at
	return best


## One step of the room (MatchAudio drives it). `excitement` < 0 means "not
## known this frame".
func tick(delta: float, excitement: float) -> void:
	clock += delta
	if _player.playing:
		_since_end = 0.0
	else:
		_since_end += delta
	if excitement >= 0.0:
		_flat = _flat + delta if excitement < STALL_EXCITEMENT else 0.0
		if _flat >= STALL_SECONDS and clock >= STALL_AFTER and _after_bell < 0.0:
			_reason(&"chant_boring")
			_flat = 0.0
	if _after_bell >= 0.0:
		var was := _after_bell
		_after_bell += delta
		if _winner_favor > 0.0 and was < DESERVE_DELAY and _after_bell >= DESERVE_DELAY:
			_start("chant_you_deserve_it")
		if clock >= ONE_MORE_AFTER and was < ONE_MORE_DELAY and _after_bell >= ONE_MORE_DELAY:
			_start("chant_one_more_match")
		return
	if _entrance != "":
		_tick_entrance(delta)
	for chant: StringName in _reasons.keys():
		if clock - float(_reasons[chant]) > REASON_LIFE:
			_reasons.erase(chant)
	var chant := pick(_reasons, _last, clock, _since_end, _player.playing)
	if chant != "":
		_reasons.erase(StringName(chant))
		_start(chant)


func _tick_entrance(delta: float) -> void:
	var was := _entrance_t
	_entrance_t += delta
	match _entrance:
		"cody":
			for at: float in CODY_WHOAS:
				if was < at and _entrance_t >= at:
					if sfx:
						sfx.play_any("crowd_whoa", -2.0, 0.0)
			if was < CODY_NAME_AT and _entrance_t >= CODY_NAME_AT:
				_start("chant_cody")
		"roman":
			if was < ROMAN_OTC_AT and _entrance_t >= ROMAN_OTC_AT:
				_start("chant_otc")


func _start(chant: String) -> void:
	if not sung_here(chant):
		return
	var take := take_of(chant)
	if take == "":
		return
	_player.stream = SfxPool.stream(take)
	_player.volume_db = CHANT_DB
	_player.play()
	_since_end = 0.0
	_last[StringName(chant)] = clock
	chanted.emit(chant)
