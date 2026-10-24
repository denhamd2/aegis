extends Resource
class_name FootballMatchVenue
## Match-owned profile: no mutable global terrain mode can leak across scenes.
@export var id: StringName = &"kilmore_drive"
@export var display_name := "Kilmore Drive"
@export var location := "Dublin"
@export var uneven_ground := true
@export var worn_surface := true
const IDS := [&"kilmore_drive", &"rovers_arena"]

static func valid_id(value: StringName) -> StringName:
	return value if value in IDS else &"kilmore_drive"

static func from_id(value: StringName) -> FootballMatchVenue:
	var venue := FootballMatchVenue.new()
	venue.id = valid_id(value)
	if venue.id == &"rovers_arena":
		venue.display_name = "Rovers Arena"
		venue.uneven_ground = false
		venue.worn_surface = false
	return venue

func camera_anchor(kind: StringName) -> Vector3:
	if kind == &"wide": return Vector3(-25,16,39) if id == &"rovers_arena" else Vector3(12,5.2,40)
	if kind == &"wide_end": return Vector3(-21,15.8,38) if id == &"rovers_arena" else Vector3(7,5,38)
	if kind == &"detail": return Vector3(46,.22,-2.6)
	return Vector3.ZERO
