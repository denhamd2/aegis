extends Resource
class_name FootballerProfile
## Character-sheet identity and a role-neutral starting slot for the 4v4 slice.

@export var player_id: StringName
@export var display_name := "Unnamed Player"
@export_range(0, 99) var jersey_number := 0
@export_enum("outfield", "goalkeeper") var role := "outfield"
@export var visual_base := ""
@export_enum("keeper", "left", "center", "right") var starting_slot := "center"
## Position in metres in the team's attacking coordinate frame; mirror X for the away side.
@export var starting_position := Vector2.ZERO
@export var attributes: FootballAttributes
