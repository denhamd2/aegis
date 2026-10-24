extends Node
## Default keyboard bindings for the first Beechlawn match slice.

const KEYS := {
	"move_left": [KEY_A], "move_right": [KEY_D],
	"move_up": [KEY_W], "move_down": [KEY_S],
	"sprint": [KEY_SHIFT], "close_control": [KEY_CTRL],
	"pass": [KEY_E], "through_pass": [KEY_Q], "tackle": [KEY_F],
	"contain": [KEY_J], "teammate_pressure": [KEY_H],
	"shield": [KEY_K], "ball_roll": [KEY_U], "step_over": [KEY_I],
	"body_feint": [KEY_O], "drag_back": [KEY_P], "skill_turn": [KEY_L], "fake_shot": [KEY_B],
	"slide_tackle": [KEY_G], "shoot": [KEY_SPACE],
	"lofted_pass": [KEY_R], "cross": [KEY_T],
	"finesse_modifier": [KEY_Z], "power_modifier": [KEY_X], "low_modifier": [KEY_V],
	"aim_left": [KEY_LEFT], "aim_right": [KEY_RIGHT],
	"aim_up": [KEY_UP], "aim_down": [KEY_DOWN], "debug": [KEY_F3],
	"switch_player": [KEY_TAB],
}

func _enter_tree() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
	for action: String in KEYS:
		for code: Key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
