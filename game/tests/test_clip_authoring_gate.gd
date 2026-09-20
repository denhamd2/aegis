extends GdUnitTestSuite
## A tripwire on the two files that decide what every clip in the match looks
## like.
##
## Why this exists
## ---------------
## CLAUDE.md's routing table already sends clip authoring to the
## `blender-animation` skill. A pass was written anyway that skipped it,
## derived the rig's axis conventions by trial, got the mirrored bones
## backwards, and shipped 29 clips with the arms hanging at the sides in every
## one of them. A routing table is read before a task; the mistake happens
## during one.
##
## What this can and cannot do
## ---------------------------
## It CANNOT verify that anyone read anything. Nothing can. What it does is
## make changing the authoring surface a deliberate act: the pinned digest
## below stops matching the moment either file is edited, and the only way
## past is to come here, read what the failure says, and re-pin. That buys one
## forced pause at exactly the point the previous pass needed one and did not
## get it.
##
## It is a speed bump, not a lock, and it is worth being honest that someone
## can re-pin without reading. The value is that they cannot do it by
## accident.
##
## When this fails
## ---------------
## 1. Read `.claude/skills/blender-animation/SKILL.md` -- bone spaces,
##    F-curves, easing. That is the one that was skipped.
## 2. Render what you changed through `tools/probe/clip_shot.tscn` and LOOK at
##    it. Every defect in the previous pass was visible on a frame and none of
##    them were visible in the numbers.
## 3. Re-run `python3 game/tools/blender/wrestling_clips.py`, then
##    `godot4 --headless --path game --import`, then the strike/paired bakes.
## 4. Update the digest below to the one the failure prints.

## sha256 of each authoring file, as last reviewed.
##
## wrestling_clips.py -- the pose tables: what every clip in the game is.
## rig_pose.py        -- the IK solver those tables are expressed against, so
##                       a change here silently moves EVERY clip at once.
const PINNED := {
	"res://tools/blender/wrestling_clips.py":
		"9c63aeb319794ba158834af6c1035c3756c66d25c8629a4c034f766a0fb6a016",
	"res://tools/blender/rig_pose.py":
		"fb1d5e5801d0d1ef1fbfec92af57f4f769794a866f83423cba60be74b4824d6a",
}

## The citation the authoring file has to keep carrying. Deleting the reminder
## is itself a change worth failing on, and the digest alone would not say
## which part of the file moved.
const CITED_SKILL := "blender-animation"


func _digest(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(file.get_buffer(file.get_length()))
	return ctx.finish().hex_encode()


func test_the_authoring_files_are_readable_at_all() -> void:
	# Guards the guard: a typo'd path would make every check below pass
	# vacuously by comparing "" to "", which is the failure mode a tripwire
	# can least afford.
	for path: String in PINNED:
		assert_str(_digest(path)) \
			.override_failure_message("%s cannot be read" % path) \
			.is_not_empty()


func test_the_clip_authoring_surface_has_not_changed_unreviewed() -> void:
	for path: String in PINNED:
		var actual := _digest(path)
		assert_str(actual) \
			.override_failure_message(
				"%s changed.\n\n" % path
				+ "Before re-pinning: read .claude/skills/%s/SKILL.md, " % CITED_SKILL
				+ "render what you changed through tools/probe/clip_shot.tscn, "
				+ "and look at the frames.\n\n"
				+ "Then set its entry in PINNED to:\n  %s" % actual) \
			.is_equal(PINNED[path])


func test_the_authoring_file_still_points_at_the_skill() -> void:
	var file := FileAccess.open("res://tools/blender/wrestling_clips.py",
			FileAccess.READ)
	assert_object(file).is_not_null()
	assert_str(file.get_as_text()) \
		.override_failure_message(
			"wrestling_clips.py no longer names the %s skill. The reminder "
			% CITED_SKILL
			+ "lives in its docstring because that is what is open when "
			+ "someone edits a pose.") \
		.contains(CITED_SKILL)
