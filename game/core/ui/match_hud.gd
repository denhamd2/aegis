class_name MatchHUD
extends Control
## The match HUD: two corner vitality plates, a three-count, and the
## submission hold meter.
##
## There was no HUD at all before this -- no CanvasLayer, Control or Label
## anywhere in the project -- which also meant the evidence gate's
## hud_present check (ARCHITECTURE.md's capture pipeline) could never pass.
##
## Every layout and colour decision below traces to gauntlet/refs/hud.md,
## which is measured from reference screenshots plus one gameplay clip.
## Where it says something is unmeasured, this says so rather than inventing
## a number: exact pixel sizing is marked pending there, so everything here
## is a fraction of the viewport instead of an absolute size.
##
## Read-only over gameplay state, and updated in _process rather than
## _physics_process, so it sits entirely off the deterministic tick and
## cannot change what a match does.

## Plate width as a fraction of viewport width. hud.md: "roughly 15-20% of
## screen width, proportioned wider than tall".
const PLATE_WIDTH_FRACTION := 0.18
const PLATE_ASPECT := 0.34
const MARGIN_FRACTION := 0.022

## hud.md's one cross-shot-consistent colour rule: the vitality bar is green
## while healthy and damage is a *revealed red segment* at the depleted end,
## never a full-bar recolour or a gradient.
const VITALITY_GREEN := Color(0.24, 0.72, 0.28)
const VITALITY_RED := Color(0.78, 0.16, 0.14)
## "Dark, low-contrast panel behind white name text in every shot."
const PLATE_BG := Color(0.06, 0.06, 0.08, 0.82)
const PLATE_EDGE := Color(0.0, 0.0, 0.0, 0.55)
const NAME_COLOR := Color(0.96, 0.96, 0.96)

## Fallback per-wrestler accent for the momentum bar and the plate flash.
## The colour actually drawn is the wrestler's own attire_accent -- read off
## him rather than duplicated here, so the plate and the man in the ring
## cannot drift apart; these are only used for a wrestler that has none.
##
## hud.md has exactly one
## reference showing a second stacked bar (blue on one wrestler, orange on
## the other) and explicitly declines to call it a rule -- so this is a
## project choice consistent with one observation, not a measured fact.
## Momentum earns the space because it gates the entire move ladder
## (power -> signature -> finisher) and is otherwise invisible.
const MOMENTUM_A := Color(0.28, 0.55, 0.92)
const MOMENTUM_B := Color(0.93, 0.55, 0.18)
const MOMENTUM_EMPTY := Color(0.16, 0.16, 0.18)
const THRESHOLD_TICK := Color(1, 1, 1, 0.45)

## "A horizontal two-color bar ... center-bottom labeled HOLD, split red
## (attacker side) / blue (defender side)."
const HOLD_ATTACKER := Color(0.80, 0.18, 0.16)
const HOLD_DEFENDER := Color(0.22, 0.46, 0.86)
const HOLD_BG := Color(0.06, 0.06, 0.08, 0.82)

@export var wrestler_a_path: NodePath
@export var wrestler_b_path: NodePath
@export var referee_path: NodePath

var wrestler_a: WrestlerController
var wrestler_b: WrestlerController
var referee: MatchReferee

func _ready() -> void:
	wrestler_a = get_node_or_null(wrestler_a_path)
	wrestler_b = get_node_or_null(wrestler_b_path)
	referee = get_node_or_null(referee_path)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var plate := Vector2(view.x * PLATE_WIDTH_FRACTION, 0.0)
	plate.y = plate.x * PLATE_ASPECT
	var margin := view.x * MARGIN_FRACTION

	# hud.md: bottom-left for the player-1-side wrestler, bottom-right for
	# the player-2 side, inset a small margin from the screen edge.
	if wrestler_a:
		_draw_plate(Vector2(margin, view.y - plate.y - margin), plate,
				wrestler_a, MOMENTUM_A, false)
	if wrestler_b:
		_draw_plate(Vector2(view.x - plate.x - margin, view.y - plate.y - margin),
				plate, wrestler_b, MOMENTUM_B, true)

	if referee:
		_draw_count(view)
		_draw_hold(view)

func _draw_plate(origin: Vector2, plate: Vector2, wrestler: WrestlerController,
		fallback_accent: Color, mirrored: bool) -> void:
	var accent: Color = wrestler.attire_accent if "attire_accent" in wrestler \
			else fallback_accent
	draw_rect(Rect2(origin, plate), PLATE_BG)
	draw_rect(Rect2(origin, plate), PLATE_EDGE, false, maxf(1.0, plate.y * 0.03))
	# A colourway flash on the plate's outer edge, in this wrestler's own
	# attire accent. Two wrestlers used to share one placeholder material,
	# so a plate could only be matched to a man by reading his name; the
	# accent is the same colour he is wearing in the ring, which is what
	# makes "who is that, and which bar is his" answerable at a glance.
	# Every reference plate in gauntlet/refs/hud.md carries a portrait in
	# this position -- there are no portraits yet, and this occupies the
	# slot with something the game can actually source.
	var flash_w := plate.x * 0.045
	var flash_x := origin.x + plate.x - flash_w if mirrored else origin.x
	draw_rect(Rect2(flash_x, origin.y, flash_w, plate.y), accent)


	var pad := plate.y * 0.14
	origin.x += 0.0 if mirrored else plate.x * 0.045
	var content_w := plate.x - plate.x * 0.045
	var font := ThemeDB.fallback_font
	var name_size := int(maxf(10.0, plate.y * 0.26))
	draw_string(font, origin + Vector2(pad, pad + name_size * 0.85),
			wrestler.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
			content_w - pad * 2.0, name_size, NAME_COLOR)

	var bar_x := origin.x + pad
	var bar_w := content_w - pad * 2.0
	var vit_h := plate.y * 0.26
	var vit_y := origin.y + pad + name_size * 1.15
	# Denominator matches CombatSystem.kickout_window_fraction()'s, so the
	# bar and the kickout difficulty can never tell different stories.
	#
	# This said the same thing while dividing by MAX_LIMB_DAMAGE * 4.0 --
	# 400, every limb destroyed -- which stopped being the kickout
	# denominator when that was rescaled to KICKOUT_DAMAGE_REFERENCE (200,
	# the range matches actually occupy). Measured off a real capture: at
	# the impact beat both bars read full green, and wrestlers are knocked
	# down between 101 and 184 damage, so a man one hit from losing showed
	# 54-75% health. The bar was describing a match this game does not play.
	var damage: float = wrestler.combat.total_damage() \
			/ CombatSystem.KICKOUT_DAMAGE_REFERENCE if wrestler.combat else 0.0
	_draw_vitality(Rect2(bar_x, vit_y, bar_w, vit_h), clampf(damage, 0.0, 1.0), mirrored)

	var mom_y := vit_y + vit_h + plate.y * 0.07
	var mom_h := plate.y * 0.13
	var momentum: float = wrestler.combat.momentum / CombatSystem.MOMENTUM_MAX \
			if wrestler.combat else 0.0
	_draw_momentum(Rect2(bar_x, mom_y, bar_w, mom_h), clampf(momentum, 0.0, 1.0),
			accent, mirrored)

## Green remaining, red revealed at the *depleted* end -- which end that is
## mirrors with the plate, so damage always eats inward from the screen edge.
func _draw_vitality(rect: Rect2, damage: float, mirrored: bool) -> void:
	draw_rect(rect, VITALITY_RED)
	var remaining := rect.size.x * (1.0 - damage)
	if remaining <= 0.0:
		return
	var x := rect.position.x + (rect.size.x - remaining) if mirrored else rect.position.x
	draw_rect(Rect2(x, rect.position.y, remaining, rect.size.y), VITALITY_GREEN)

func _draw_momentum(rect: Rect2, fill: float, accent: Color, mirrored: bool) -> void:
	draw_rect(rect, MOMENTUM_EMPTY)
	var filled := rect.size.x * fill
	if filled > 0.0:
		var x := rect.position.x + (rect.size.x - filled) if mirrored else rect.position.x
		draw_rect(Rect2(x, rect.position.y, filled, rect.size.y), accent)
	# The three rungs of the move ladder, so a player can see which tier is
	# unlocked rather than inferring it from what the wrestler does.
	for threshold: float in [CombatSystem.POWER_THRESHOLD,
			CombatSystem.SIGNATURE_THRESHOLD, CombatSystem.FINISHER_THRESHOLD]:
		var t := threshold / CombatSystem.MOMENTUM_MAX
		var tx := rect.position.x + (rect.size.x * (1.0 - t) if mirrored else rect.size.x * t)
		draw_line(Vector2(tx, rect.position.y),
				Vector2(tx, rect.position.y + rect.size.y), THRESHOLD_TICK, 1.0)

## Centre-top, and a plain pop-in: timings.md frame-stepped the digits
## appearing between one frame and the next with no fade, so nothing here
## eases.
func _draw_count(view: Vector2) -> void:
	var count := referee.pin_count()
	if count <= 0:
		return
	var font := ThemeDB.fallback_font
	var font_size := int(view.y * 0.17)
	draw_string(font, Vector2(0.0, view.y * 0.22), str(count),
			HORIZONTAL_ALIGNMENT_CENTER, view.x, font_size, NAME_COLOR)

func _draw_hold(view: Vector2) -> void:
	if not referee.is_submission_active():
		return
	var progress := referee.submission_progress()
	var bar := Vector2(view.x * 0.36, view.y * 0.030)
	var origin := Vector2((view.x - bar.x) * 0.5, view.y - bar.y - view.y * 0.10)
	draw_rect(Rect2(origin, bar), HOLD_BG)
	# A tug-of-war, so the two sides grow toward each other from the ends.
	var half := bar.x * 0.5
	draw_rect(Rect2(origin, Vector2(half * progress.x, bar.y)), HOLD_ATTACKER)
	var defender_w := half * progress.y
	draw_rect(Rect2(origin.x + bar.x - defender_w, origin.y, defender_w, bar.y),
			HOLD_DEFENDER)
	var font := ThemeDB.fallback_font
	var font_size := int(maxf(10.0, bar.y * 0.95))
	draw_string(font, Vector2(origin.x, origin.y - bar.y * 0.35), "HOLD",
			HORIZONTAL_ALIGNMENT_CENTER, bar.x, font_size, NAME_COLOR)
