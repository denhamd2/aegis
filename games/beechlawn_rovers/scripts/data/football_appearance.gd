extends Resource
class_name FootballAppearance
## Shared art references plus per-player overrides. Mesh resources stay shared.

@export_enum("beechlawn_outfield", "beechlawn_keeper", "bordeaux_outfield", "bordeaux_keeper", "referee", "spectator") var kit := "beechlawn_outfield"
@export_range(0.94, 1.06, 0.01) var height_scale := 1.0
@export_range(0.9, 1.12, 0.01) var build_scale := 1.0
@export var head_variant: PackedScene = preload("res://assets/characters/shared/heads/master.glb")
@export var hair_variant: PackedScene
@export_enum("legacy_crop", "custom", "bald") var hair_style := "legacy_crop"
@export var head_albedo: Texture2D
@export var print_name := ""
@export var skin_tint := Color.WHITE
