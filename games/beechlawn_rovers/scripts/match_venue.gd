extends Resource
class_name FootballMatchVenue
## Match-owned profile: no mutable global terrain mode can leak across scenes.
@export var id: StringName = &"kilmore_drive"
@export var display_name := "Kilmore Drive"
@export var location := "Dublin"
@export var uneven_ground := true
@export var worn_surface := true
@export_enum("park","stadium") var kind := "park"
@export var builder: Script
@export var presentation: FootballVenuePresentation
@export var goal: FootballGoalProfile
const IDS := [&"kilmore_drive", &"rovers_arena"]
const CATALOGUE := {&"kilmore_drive":"res://data/venues/kilmore_drive.tres",&"rovers_arena":"res://data/venues/rovers_arena.tres"}

static func valid_id(value: StringName) -> StringName:
	return value if value in IDS else &"kilmore_drive"

static func from_id(value: StringName) -> FootballMatchVenue:
	return (load(CATALOGUE[valid_id(value)]) as FootballMatchVenue).duplicate(true)

func camera_anchor(kind: StringName) -> Vector3:
	if presentation!=null and presentation.anchors.has(String(kind)): return presentation.anchors[String(kind)]
	if kind == &"wide": return Vector3(12,5.2,40)
	if kind == &"wide_end": return Vector3(7,5,38)
	if kind == &"detail": return Vector3(46,.22,-2.6)
	return Vector3.ZERO
