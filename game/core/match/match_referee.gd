class_name MatchReferee
extends Node
## Drives pin/submission resolution and declares the win condition.
## Grey-box version of the "ref" system: watches for a downed wrestler
## being covered or locked in a submission, runs the deterministic
## minigame, and ends the match on a three-count or a tap-out.

signal match_won(winner: WrestlerController, method: String)

## Tick each hand-slap lands on, measured rather than divided evenly.
##
## gauntlet/refs/timings.md frame-stepped a real three-count at native 30fps
## with no sampling gaps (Byron Breakker vs Oba Femi, ~1093s): "1" to "2" is
## ~1.25s and "2" to "3" ~1.00s. A real count is *uneven* -- the referee
## hangs on the first slap and speeds up into the third -- and this was an
## even 1.00s apart, which is the one thing the reference says it is not.
##
## The lead-in from the cover to "1" is measured now too, by walking the
## same pinfall backwards to the cover (timings.md, "Cover -> count '1'"):
## 3.60s in the footage, of which ~2.07s is the referee walking across the
## ring. There is no referee actor here -- a cover in this project starts
## at what the footage calls "referee in position" -- so the comparable
## half is the ~1.53s from there to the first slap, i.e. 92 ticks. It was
## 60, so the count used to start about half a second early.
const COUNT_TICKS: Array[int] = [92, 167, 227]
const PIN_COUNT_TICKS := 227

## How long each digit stays on screen, also frame-stepped: "1" is visible
## ~0.63-0.67s and "2" ~0.37-0.43s, with a silent gap of ~0.55s before the
## next one pops in. So the count is not a number that sits there changing
## -- it flashes, goes away, and comes back, which is most of what makes a
## three-count tense to watch.
const COUNT_VISIBLE_TICKS: Array[int] = [39, 24, 999]
const COVER_RANGE := 1.2
## Total damage past which a downed opponent is covered rather than locked
## in a submission. See _check_for_downed_opponent_action().
const PIN_PREFERENCE_DAMAGE := 140.0
## How often the attacker reaches for a submission when both finishes are
## available. A reachability value, not a feel claim -- refs have nothing on
## how often a wrestler should pick one over the other.
const SUBMISSION_PREFERENCE := 0.5
## Counts finish decisions so successive ones can differ; seed input only.
var _finish_choices: int = 0
## Limb damage past which a submission is worth attempting at all.
##
## Was 70. The worst limb tracks total damage at a near-constant ~0.49
## (measured at every knockdown of a full match), so 70 is reached at ~143
## total -- past PIN_PREFERENCE_DAMAGE, which left no range where both
## finishes were legal and made the seeded choice below dead code. At 55
## the overlap opens at ~112 total, which is a couple of knockdowns before
## a wrestler is finishable, so a match can go either way.
const SUBMISSION_LIMB_THRESHOLD := 55.0
## Absolute safety cap on a tie-up contest, not the primary mechanism (see
## _tick_tie_up()) — TieUpMinigame.PROGRESS_THRESHOLD is what actually
## decides it in practice.
const TIE_UP_MAX_TICKS := 200

@export var wrestler_a_path: NodePath
@export var wrestler_b_path: NodePath
@export var match_seed: int = 0
@export var reversal_counter_move: MoveDef
## Extra counters drawn between by a seeded pick when a reversal lands, in
## the same shape as WrestlerController's grapple tier pools. Empty means
## reversal_counter_move every time.
@export var reversal_move_pool: Array[MoveDef] = []
## Incremented per reversal so successive counters in a match can differ.
var _reversal_draws: int = 0

var wrestler_a: WrestlerController
var wrestler_b: WrestlerController

var _pin_ticks: int = 0
## Which count is on screen; see pin_count().
var _pin_count_shown: int = 0
var _pinning: bool = false
var _pin_attacker: WrestlerController
var _pin_defender: WrestlerController
var _submissioning: bool = false
var _submission_attacker: WrestlerController
var _submission_defender: WrestlerController
var _tying_up: bool = false
var _tie_up_ticks: int = 0
var _tie_up_minigame: TieUpMinigame
var _match_over: bool = false
## True while a reversal's paired counter animation is playing -- guards
## _check_for_reversal() from re-triggering on a later tick against the
## same attacker, who's still sitting in STRIKE/RUNNING_ATTACK (not yet
## moved to HIT_REACT) for the animation's duration. Without this, a stale
## _wants_reversal_this_tick surviving the reverser's own suspended
## _physics_process() would hit GrappleRig.begin()'s "not _active" assert
## on the very next tick.
var _reversing: bool = false

func _ready() -> void:
	wrestler_a = get_node(wrestler_a_path)
	wrestler_b = get_node(wrestler_b_path)

func _physics_process(_delta: float) -> void:
	if _match_over:
		return
	_resolve_tick()
	# Closes the tick for the replay. This is the one place in the frame
	# where every wrestler has already read its input for tick N (they run
	# earlier in the scene tree; that ordering is load-bearing enough to
	# have its own doc comment on _try_start_tie_up()), so it is the only
	# correct place to move the counter to N+1.
	#
	# Nothing called this before, anywhere, so ReplaySystem.current_tick sat
	# at 0 for entire matches: a recording overwrote frame 0 thousands of
	# times and kept only the last tick's input, and playback fed that one
	# frame to every tick of the match. The replay system has never actually
	# recorded or replayed a match, despite ARCHITECTURE.md making
	# same-seed-same-replay a hard requirement.
	#
	# Gameplay is untouched by this: in LIVE and RECORDING mode
	# ReplaySystem.get_input() returns the live input regardless of
	# current_tick. Only the recorded data changes -- from wrong to right.
	if ReplaySystem:
		ReplaySystem.advance_tick()

## The tick's actual decisions, split out from _physics_process so its
## several early returns can't skip closing the tick above.
func _resolve_tick() -> void:
	# MatchReferee runs after both wrestlers in the scene tree, so this is
	# the single point each tick where queued hits (see
	# WrestlerController._pending_hits) are resolved — after every
	# wrestler has made its own decision for the tick, symmetrically,
	# regardless of node order.
	wrestler_a._resolve_pending_hits()
	wrestler_b._resolve_pending_hits()
	_check_for_reversal()

	if _pinning:
		_tick_pin()
		return
	if _submissioning:
		_tick_submission()
		return
	if _tying_up:
		_tick_tie_up()
		return
	if _try_start_tie_up():
		return
	_check_for_downed_opponent_action()

## Starts a tie-up once either wrestler pressed grapple this tick (captured
## by WrestlerController._wants_tie_up_this_tick — see its doc comment for
## why entry lives here rather than inline in the wrestler, mirroring
## PIN_DEFENDER/SUBMISSION_DEFENDER's "driven by MatchReferee" pattern: this
## runs strictly after both wrestlers' own _physics_process for the tick, so
## neither side gets a scene-tree-order head start on the mash contest that
## follows. Also the sole gate against an illegal TIE_UP transition (only
## legal from IDLE/LOCOMOTION per WrestlerFSM.LEGAL_TRANSITIONS) — checked
## for both wrestlers before touching either FSM, same protection the old
## inline version had.
func _try_start_tie_up() -> bool:
	if not (wrestler_a._wants_tie_up_this_tick or wrestler_b._wants_tie_up_this_tick):
		return false
	if wrestler_a.global_position.distance_to(wrestler_b.global_position) > WrestlerController.TIE_UP_RANGE:
		return false
	if not WrestlerController.CAN_ENTER_TIE_UP.has(wrestler_a.fsm.current_state) \
			or not WrestlerController.CAN_ENTER_TIE_UP.has(wrestler_b.fsm.current_state):
		return false
	wrestler_a.fsm.transition_to(WrestlerFSM.State.TIE_UP)
	wrestler_b.fsm.transition_to(WrestlerFSM.State.TIE_UP)
	_tying_up = true
	_tie_up_ticks = 0
	_tie_up_minigame = TieUpMinigame.new()
	return true

## Consumes MoveDef.reversal_window_start/end -- and the "reversal" input,
## plumbed since day one but never read anywhere -- for the first time: the
## target of an in-flight STRIKE or RUNNING_ATTACK can cancel the incoming
## hit by pressing reversal while the attacker's move is inside its own
## reversal window. Runs here (after both wrestlers' _physics_process for
## the tick, before _resolve_pending_hits() would ever see a hit this
## reversal is meant to cancel) for the same reason tie-up entry and
## pending-hit resolution already do: whether a reversal lands depends on
## reading the *opponent's* same-tick state
## (_active_move/_move_ticks_remaining), and resolving that inline in
## either wrestler's own _physics_process() would make the outcome depend
## on scene-tree node order -- the exact bug class already fixed twice this
## session for tie-up entry and pending hits.
##
## MOVE_EXEC (a grapple move resolved via GrappleRig) is deliberately not
## included here: _resolve_grapple_move() enters and resolves MOVE_EXEC
## synchronously within the attacker's own single _physics_process() call
## (no ticks pass in between), so by the time this referee tick runs, a
## grapple-driven MOVE_EXEC is already over -- there's no multi-tick window
## for a reversal to observe. strike_jab.tres already has a real
## reversal_window_start/end (6-9) waiting on exactly this consumer, though.
func _check_for_reversal() -> void:
	if _reversing:
		return
	for pair in [[wrestler_a, wrestler_b], [wrestler_b, wrestler_a]]:
		var reverser: WrestlerController = pair[0]
		var attacker: WrestlerController = pair[1]
		if not reverser._wants_reversal_this_tick:
			continue
		if not attacker._active_move or not attacker.fsm.is_in([WrestlerFSM.State.STRIKE, WrestlerFSM.State.RUNNING_ATTACK]):
			continue
		var frame_offset := attacker._active_move.total_frames() - attacker._move_ticks_remaining
		if not attacker._active_move.is_in_reversal_window(frame_offset):
			continue
		if reverser.global_position.distance_to(attacker.global_position) > WrestlerController.STRIKE_HIT_RANGE:
			continue
		_apply_reversal(reverser, attacker)
		# One reversal per tick, and the first pair in iteration order wins
		# it. Both wrestlers can legitimately be inside each other's
		# reversal window on the same tick -- rapid mutual strike-trading is
		# the norm in this match loop, and gauntlet/refs/timings.md notes
		# the reference footage is full of it -- and _reversing was only
		# read once, above the loop, so the second pair applied a reversal
		# on top of the first: GrappleRig.begin() asserts `not _active` and
		# the match died there. Breaking is the whole fix; the loser of the
		# race simply eats the hit, which is what a reversal is for.
		return

## Negates the incoming hit and gives the attacker a taste of their own
## medicine -- HIT_REACT, plus the reverser (not the attacker) keeps the
## move's momentum, a small comeback reward. Not a full "counter move"
## system: the reverser doesn't deal the move's damage back, just avoids it
## and gets the momentum, matching how much of a mechanic gauntlet/refs'
## still-pending reversal-window research actually justifies right now.
##
## Plays a real paired counter animation (reversal_counter.tres) via the
## reverser's own GrappleRig reference -- reused exactly like a normal
## grapple move, with the reverser in the "attacker" role (the one whose
## motion track drives the counter) and the original attacker in the
## "defender" role (the one getting countered). Finalizing HIT_REACT/
## momentum waits for the animation to actually finish (grapple_finished)
## rather than happening immediately, the same async shape
## _process_grapple_hold()/_on_grapple_finished() already use for normal
## grapple moves.
func _apply_reversal(reverser: WrestlerController, attacker: WrestlerController) -> void:
	_reversing = true
	var grapple_rig := reverser.grapple_rig
	var counter := _pick_counter()
	if grapple_rig and counter:
		grapple_rig.grapple_finished.connect(_on_reversal_finished.bind(reverser, attacker), CONNECT_ONE_SHOT)
		grapple_rig.begin(reverser, attacker, counter)
	else:
		_finish_reversal(reverser, attacker)

## Seeded draw across reversal_counter_move plus reversal_move_pool. A
## counter negates a hit and hands the reverser momentum, so which one plays
## is gameplay, not decoration -- it has to be reproducible from the seed.
func _pick_counter() -> MoveDef:
	if reversal_move_pool.is_empty():
		return reversal_counter_move
	var choices: Array[MoveDef] = []
	if reversal_counter_move:
		choices.append(reversal_counter_move)
	for candidate: MoveDef in reversal_move_pool:
		if candidate:
			choices.append(candidate)
	if choices.is_empty():
		return reversal_counter_move
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 8192 + 7919 + _reversal_draws
	_reversal_draws += 1
	return choices[rng.randi_range(0, choices.size() - 1)]

func _on_reversal_finished(_attacker: Node3D, _defender: Node3D, reverser: WrestlerController, attacker: WrestlerController) -> void:
	_finish_reversal(reverser, attacker)

func _finish_reversal(reverser: WrestlerController, attacker: WrestlerController) -> void:
	var reversed_move := attacker._active_move
	# _start_move() below immediately overwrites _active_move with the
	# HIT_REACT timed stub anyway (same as _go_down()/_resolve_pending_hits()
	# already do), so there's no separate "clear it first" step needed here
	# -- the stub itself is what blocks the active-frame hit-application
	# branch in _process_active_move() from ever seeing the reversed move
	# again.
	attacker._start_move(WrestlerFSM.State.HIT_REACT, attacker._timed_stub(WrestlerController.HIT_REACT_TICKS))
	reverser.combat.apply_momentum(reversed_move)
	_reversing = false

## Kept as one function rather than two independent scans so a given
## attacker/defender pair can't match both a pin and a submission check the
## same tick — each pair gets exactly one decision.
func _check_for_downed_opponent_action() -> void:
	for pair in [[wrestler_a, wrestler_b], [wrestler_b, wrestler_a]]:
		var attacker: WrestlerController = pair[0]
		var defender: WrestlerController = pair[1]
		if defender.fsm.current_state == WrestlerFSM.State.DOWN \
				and defender._cover_eligible \
				and attacker.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
				and attacker.global_position.distance_to(defender.global_position) <= COVER_RANGE:
			var worst_limb: CombatSystem.Limb = defender.combat.most_damaged_limb()
			# A worn-down opponent gets covered, not stretched. The rule used
			# to be "worst limb past 70 -> submission" with no upper bound,
			# which sent every late knockdown to a submission -- precisely
			# when the man is most pinnable -- so a pinfall could never
			# happen. Measured over a match: knockdowns at 101..136 total
			# damage all became pins the defender escaped, and the first one
			# at 146 became the submission that ended it.
			#
			# Below PIN_PREFERENCE_DAMAGE, with a limb worked past the
			# submission threshold, either finish is on -- and which one he
			# reaches for is a seeded choice, so a match is not the same
			# script every time. A hard threshold on total damage is not a
			# decision, it is a schedule: the worst limb tracks total damage
			# at a near-constant ~0.49 (measured across every knockdown in a
			# match), so any pair of fixed thresholds either makes one
			# finish unreachable or the other inevitable. Both extremes were
			# measured here: 12 of 12 seeds submission before, 12 of 12
			# pinfall after the first attempt at this.
			if defender.combat.total_damage() < PIN_PREFERENCE_DAMAGE \
					and defender.combat.limb_damage[worst_limb] >= SUBMISSION_LIMB_THRESHOLD \
					and _prefers_submission():
				_submissioning = true
				_submission_attacker = attacker
				_submission_defender = defender
				attacker.begin_submission(defender, worst_limb)
			else:
				_pinning = true
				_pin_ticks = 0
				_pin_count_shown = 0
				_pin_attacker = attacker
				_pin_defender = defender
				attacker.begin_pin(defender, _pin_seed())
			return

## Seed for this pin's kickout minigame. Every pin in a match needs its own
## target window, so the seed has to vary -- but only with match state.
##
## This used to be `match_seed + Engine.get_physics_frames()`, and
## get_physics_frames() is a *process*-global counter, not a per-match one.
## Replay the same recording in a process that reaches the pin at a
## different global frame -- a capture that plays a replay after a menu, or
## simply the second match run in one process -- and the defender gets a
## different kickout window, so the same inputs produce a different match.
## That is precisely the guarantee ARCHITECTURE.md calls a hard requirement,
## and the capture pipeline is built on top of it.
##
## ReplaySystem.current_tick is the same quantity the seed wanted (how far
## into the match this pin is) except that it resets with the match and is
## reproduced exactly by playback.
func _pin_seed() -> int:
	var tick: int = ReplaySystem.current_tick if ReplaySystem else _pin_ticks
	return match_seed + tick

## Whether this attacker reaches for the submission rather than the cover,
## when the defender's state allows either.
##
## Seeded like every other decision that changes a match, and deliberately
## using different multipliers from the counter draw so the two do not move
## together.
func _prefers_submission() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 4099 + _finish_choices * 37
	_finish_choices += 1
	return rng.randf() < SUBMISSION_PREFERENCE

## Read-only views of referee state, for the HUD.
##
## The HUD polls these in _process rather than being pushed to, so it stays
## entirely off the physics tick -- it can never change what a tick does,
## which is the whole reason it is allowed to read gameplay state at all.

## Which hand-slap the referee is on: 0 before the first, up to 3. Digits
## pop in with no fade (gauntlet/refs/hud.md, frame-stepped), so this is a
## plain step function and the HUD needs no easing.
## Latched rather than derived from _pin_ticks, because the third count and
## the end of the pin land on the same tick: _tick_pin() sees 180 ticks,
## declares the pinfall and clears _pinning in one call, so a count computed
## live would blink "3" for zero frames and the winning count -- the one
## moment the number matters most -- would never be on screen. Cleared when
## a new pin starts or the defender kicks out; held afterwards, the way a
## broadcast leaves the count up over the finish.
func pin_count() -> int:
	return _pin_count_shown

func is_pin_active() -> bool:
	return _pinning

func is_submission_active() -> bool:
	return _submissioning

## Both sides of the submission tug-of-war as 0..1 fractions: x is the
## attacker closing on the defender's breaking point, y the defender working
## free. gauntlet/refs/hud.md confirms this as a real on-screen element (a
## centre-bottom red/blue "HOLD" bar) that this project never rendered.
func submission_progress() -> Vector2:
	if not _submissioning or not _submission_defender:
		return Vector2.ZERO
	var minigame: SubmissionMinigame = _submission_defender._submission_minigame
	if not minigame:
		return Vector2.ZERO
	return Vector2(
		minigame.attacker_progress / SubmissionMinigame.BREAK_POINT,
		minigame.defender_progress / SubmissionMinigame.BREAK_POINT)

func _tick_pin() -> void:
	_pin_ticks += 1
	if _pin_defender._pin_minigame and _pin_defender._pin_minigame.tick(_pin_ticks, _pin_defender._kickout_input_this_tick):
		_end_pin(false)
		return
	_update_count()
	if _pin_ticks >= PIN_COUNT_TICKS:
		_end_pin(true)

## Which digit is on screen this tick, from the measured schedule: a slap
## lands at COUNT_TICKS[i] and its digit is up for COUNT_VISIBLE_TICKS[i],
## then nothing until the next one.
func _update_count() -> void:
	_pin_count_shown = 0
	for i in COUNT_TICKS.size():
		if _pin_ticks < COUNT_TICKS[i]:
			break
		if _pin_ticks < COUNT_TICKS[i] + COUNT_VISIBLE_TICKS[i]:
			_pin_count_shown = i + 1
			break

func _end_pin(three_count_reached: bool) -> void:
	_pinning = false
	_pin_attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	if three_count_reached:
		_declare_winner(_pin_attacker, "pinfall")
	else:
		_pin_count_shown = 0
		_pin_defender.fsm.transition_to(WrestlerFSM.State.DOWN)
		_pin_defender._move_ticks_remaining = WrestlerController.GETUP_TICKS
		# Not cover-eligible again until this wrestler actually reaches IDLE
		# (DOWN -> GETUP -> IDLE) — otherwise, since the attacker is also
		# reset to IDLE right where it was standing (already in cover
		# range), _check_for_downed_opponent_action() would re-match on the
		# very next tick, forever, with no time for a getup or a fresh hit
		# to ever land.
		_pin_defender._cover_eligible = false

## Attacker's side of the race needs no continued input (mirrors
## PIN_ATTACKER's automatic three-count) — only the defender's hold state,
## captured each tick by WrestlerController, matters.
func _tick_submission() -> void:
	var minigame: SubmissionMinigame = _submission_defender._submission_minigame
	minigame.tick(true, _submission_defender._submission_defender_input_this_tick)
	var tapped := minigame.attacker_wins()
	var escaped := minigame.defender_escapes()
	if tapped and escaped:
		# Both rings break on the same tick. Not hypothetical: the referee
		# only starts a hold in a narrow band of limb damage around
		# WrestlerController.SUBMISSION_ESCAPE_LIMB, where the two rates
		# are close, and a limb sitting exactly on the crossover makes them
		# identical -- 2 of 10 measured seeds landed there. Resolved with
		# an explicit seeded flip for the same reason _tick_tie_up() does:
		# left to the if/elif's ordering, "the attacker wins ties" is a
		# rule nobody chose, hidden in the checking order.
		_end_submission(_break_submission_tie())
	elif tapped:
		_end_submission(true)
	elif escaped:
		_end_submission(false)

## Seeded, like the tie-up's own tie-break: same (match_seed, hold count)
## always resolves the same way, so a replay reproduces it, but successive
## dead heats in a match and across seeds do not all go one way.
func _break_submission_tie() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 6143 + _finish_choices * 41
	return rng.randi_range(0, 1) == 0

func _end_submission(tapped_out: bool) -> void:
	_submissioning = false
	_submission_attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	if tapped_out:
		_declare_winner(_submission_attacker, "submission")
	else:
		_submission_defender.fsm.transition_to(WrestlerFSM.State.DOWN)
		_submission_defender._move_ticks_remaining = WrestlerController.GETUP_TICKS
		# Same re-cover-exploit protection proven for kickouts (see _end_pin)
		# — an escaped submission must not instantly re-trigger a new
		# pin/submission on the very next tick either.
		_submission_defender._cover_eligible = false

## Both sides mash "grapple" (captured per-tick by WrestlerController);
## whoever accumulates more qualifying presses first becomes the grapple
## attacker. Unlike pin/submission there's no pre-existing attacker/defender
## role here — the contest itself decides it.
func _tick_tie_up() -> void:
	_tie_up_ticks += 1
	_tie_up_minigame.tick(wrestler_a._tie_up_input_this_tick, wrestler_b._tie_up_input_this_tick)
	var a_won := _tie_up_minigame.a_wins()
	var b_won := _tie_up_minigame.b_wins()
	if a_won and b_won:
		# Both sides crossed PROGRESS_THRESHOLD on the exact same tick — now
		# a real, reachable case (not just a hypothetical) once entry-order
		# bias is fixed and two AI opponents mash on genuinely equal
		# footing (see _try_start_tie_up()'s doc comment and
		# WrestlerAI.setup_jitter(), which makes an exact tie rare but not
		# impossible). Resolved with an explicit, seeded coin flip rather
		# than silently falling out of an if/elif's checking order — that
		# was the original bug's own shape (the old placeholder's "lower
		# player_index wins" rule), just relocated, not fixed, if left
		# implicit here too.
		var winner := _break_tie_up_tie()
		_resolve_tie_up(winner, wrestler_b if winner == wrestler_a else wrestler_a)
	elif a_won:
		_resolve_tie_up(wrestler_a, wrestler_b)
	elif b_won:
		_resolve_tie_up(wrestler_b, wrestler_a)
	elif _tie_up_ticks >= TIE_UP_MAX_TICKS:
		# Backstop only — distinct AI/press policies make an exact tie
		# between two independent deterministic mash rates unlikely, but
		# this guarantees the match can't stall here forever.
		var attacker := wrestler_a if _tie_up_minigame.a_progress >= _tie_up_minigame.b_progress else wrestler_b
		_resolve_tie_up(attacker, wrestler_b if attacker == wrestler_a else wrestler_a)

## Seeded, not random-random: same (match_seed, _tie_up_ticks) pair always
## picks the same winner (ReplaySystem determinism), but varies across
## matches/seeds and across repeated ties within one match, unlike a bare
## "lower index wins" rule.
func _break_tie_up_tie() -> WrestlerController:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 4096 + _tie_up_ticks
	return wrestler_a if rng.randi_range(0, 1) == 0 else wrestler_b

func _resolve_tie_up(attacker: WrestlerController, defender: WrestlerController) -> void:
	_tying_up = false
	attacker._is_grapple_attacker = true
	defender._is_grapple_attacker = false
	attacker.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	defender.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)

func _declare_winner(winner: WrestlerController, method: String) -> void:
	_match_over = true
	match_won.emit(winner, method)
