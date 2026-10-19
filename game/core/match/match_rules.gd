class_name MatchRules
extends RefCounted
## Which match this is, chosen on the select screen (TitleScreen) and carried
## on the match scene's root as metadata, so anything in the match reads it
## the same way without a reference to the menu.
##
##   ONE_ON_ONE        the singles match as it has always been;
##   NO_HOLDS_BARRED   anything goes: no disqualification, no count-out, pins
##                     anywhere, the fight goes outside, and the weapons come
##                     out from under the ring (gauntlet/refs/weapons_nhb.md).

enum Mode { ONE_ON_ONE, NO_HOLDS_BARRED }

## As the select screen and the VS card print them, by Mode. The anything-goes
## match is billed as a LIGHTS OUT match, AEW's name for it (the owner,
## 19 Oct); in the code it stays NO_HOLDS_BARRED, the rules it plays by.
const LABELS := ["1 ON 1", "LIGHTS OUT"]
const META := &"match_mode"


static func set_mode(scene: Node, mode: int) -> void:
	scene.set_meta(META, mode)


## The mode of the match `node` is in: read off the current scene's root, or
## off `node` itself when it is the root (a probe's un-entered instance).
static func mode_of(node: Node) -> int:
	if node.has_meta(META):
		return int(node.get_meta(META))
	var tree := node.get_tree() if node.is_inside_tree() else null
	var root := tree.current_scene if tree else null
	if root and root.has_meta(META):
		return int(root.get_meta(META))
	var up := node.get_parent()
	while up:
		if up.has_meta(META):
			return int(up.get_meta(META))
		up = up.get_parent()
	return Mode.ONE_ON_ONE


static func no_holds_barred(node: Node) -> bool:
	return mode_of(node) == Mode.NO_HOLDS_BARRED


static func label(mode: int) -> String:
	return LABELS[clampi(mode, 0, LABELS.size() - 1)]
