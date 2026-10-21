extends RefCounted
## Original camera families; distances/FOV are Godot tuning, not PES parameters.
## Sideline views share the opposite touchline, keeping a consistent match axis.
const DEFAULT := &"close_broadcast"
const PRESETS := {
	&"close_broadcast": {"name": "Close Broadcast", "offset": Vector3(0, 12, -26), "fov": 50.0, "mode": &"follow"},
	&"dynamic_wide": {"name": "Dynamic Wide", "offset": Vector3(0, 16, -32), "fov": 52.0, "mode": &"follow"},
	&"stadium": {"name": "Stadium", "offset": Vector3(0, 19, -43), "fov": 55.0, "mode": &"tripod"},
	&"live_broadcast": {"name": "Live Broadcast", "offset": Vector3(0, 11, -37), "fov": 42.0, "mode": &"tripod"},
	&"fan_view": {"name": "Fan View", "offset": Vector3(0, 22, -40), "fov": 58.0, "mode": &"follow"},
	&"blimp": {"name": "Blimp / Tactical", "offset": Vector3(0, 65, 0.05), "fov": 60.0, "mode": &"overhead"},
	&"vertical": {"name": "Vertical", "offset": Vector3(-24, 16, 0), "fov": 55.0, "mode": &"end_to_end"},
	&"player": {"name": "Player", "offset": Vector3(-7, 4.5, 0), "fov": 64.0, "mode": &"player"},
	&"field_side": {"name": "Field Side", "offset": Vector3(0, 4.5, -22), "fov": 60.0, "mode": &"follow"},
}

static func valid_id(value: StringName) -> StringName:
	return value if PRESETS.has(value) else DEFAULT
