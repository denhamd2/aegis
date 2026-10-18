extends Resource
class_name FootballerProfile
## Identity, formation assignment and reusable appearance; ratings default neutral.

@export var player_id: StringName
@export var display_name := "Unnamed Player"
@export_range(0, 99) var jersey_number := 0
@export_enum("outfield", "goalkeeper") var role := "outfield"
@export var visual_base := ""
@export var starting_slot := "center"
@export_enum("goalkeeper", "fullback", "centre_back", "central_midfielder", "winger", "striker") var tactical_role := "central_midfielder"
@export var appearance: FootballAppearance
## Position in metres in the team's attacking coordinate frame; mirror X for the away side.
@export var starting_position := Vector2.ZERO
@export var attributes: FootballAttributes
