extends Resource
class_name FootballVenuePresentation
## Author landmarks in venue space; no stadium camera coordinates in the director.
@export var anchors: Dictionary = {}
@export var tifo:FootballTifoProfile
@export var exterior_haze_begin:=0.0
@export var exterior_haze_end:=1600.0
@export var opening_shots: Array[Dictionary] = []
@export var exterior_bounds := AABB(Vector3(-250,-5,-250),Vector3(500,150,500))
@export var crowd_close_anchor := Vector3(-72,5.5,18)

func anchor(id: StringName, fallback: Vector3) -> Vector3:
	return anchors.get(String(id),fallback)

func resolved_shots() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for original in opening_shots:
		var shot:=original.duplicate(true)
		var source:=String(shot.get("anchor","bowl"))
		var target:=String(shot.get("target","pitch"))
		shot["from"]=anchors.get(source,anchors.get("bowl",Vector3(-24,18,40)))
		shot["to"]=shot["from"]+Vector3(shot.get("dolly",Vector3(1,0,0)))
		shot["look_from"]=anchors.get(target,Vector3(0,.8,0))
		shot["look_to"]=shot["look_from"]
		result.append(shot)
	return result
