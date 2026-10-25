extends Resource
class_name FootballGraphicsProfile
## Quality changes affect presentation only; physics always retains its cadence.
const IDS: Array[StringName] = [&"balanced_60", &"custom"]
const LABELS := ["Balanced 60", "Custom / full resolution"]
@export var id: StringName = &"balanced_60"
@export var fps_limit := 60
@export var max_3d_size := Vector2i(1920,1080)
@export var minimum_quality := .8
@export var maximum_quality := 1.0
@export var gpu_budget_ms := 14.5
@export var gameplay_hero_fans := 16
@export var cinematic_hero_fans := 32

static func valid_id(value: StringName) -> StringName:
	return value if value in IDS else &"balanced_60"

static func from_id(value: StringName) -> FootballGraphicsProfile:
	var profile := FootballGraphicsProfile.new()
	profile.id = valid_id(value)
	if profile.id == &"custom": profile.fps_limit=0
	return profile
