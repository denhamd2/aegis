extends GdUnitTestSuite
## The CC0 base rig faces the opposite way to Godot's convention, and
## scenes/wrestler.tscn carries a 180-degree yaw on CharacterModel to cancel
## that out. This suite exists so nobody "tidies away" that rotation.
##
## Evidence, from parsing assets/characters/wrestler_base_root_motion.glb
## directly: the forward-locomotion clips translate the rig's `root` node
## along +Z -- Walk_Loop dZ=+1.3, Jog_Fwd_Loop dZ=+5.0, Sprint_Loop dZ=+5.5,
## all with dX=0. Godot treats -Z as forward, which is what every look_at()
## and -basis.z in this project assumes (WrestlerController's movement
## facing, _turn_toward_opponent(), GrappleRig's pair frame, MatchCamera).
##
## Without the compensating yaw the *node* aims correctly at the opponent
## while the *rendered character* faces exactly away -- which is invisible to
## any transform-based assertion, and shipped once for exactly that reason:
## a measured forward-dot-to-opponent of 1.0 was reported as "facing fixed"
## while a capture of the same build showed both wrestlers pointing away from
## each other.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")

func _make_wrestler() -> WrestlerController:
	var wrestler: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(wrestler)
	return wrestler

func test_character_model_cancels_the_rigs_backwards_forward_axis() -> void:
	var wrestler := _make_wrestler()
	var model := wrestler.get_node_or_null("CharacterModel") as Node3D
	assert_object(model).override_failure_message(
		"wrestler.tscn must keep a CharacterModel child for the yaw to live on"
	).is_not_null()

	# The mesh's visual forward, expressed in the body's own space. With the
	# rig authored +Z-forward and the node yawed 180 degrees, this lands on
	# the body's -Z -- Godot's forward, and what the gameplay code aims.
	var model_visual_forward := model.transform.basis * Vector3.BACK
	assert_vector(model_visual_forward).override_failure_message(
		"CharacterModel's visual forward must line up with the body's -Z; " +
		"got %v. See this suite's header before changing it." % model_visual_forward
	).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 0.001)

## Guards the yaw specifically, not just any transform: a uniform scale or a
## translation on this node would leave the facing wrong in a way the check
## above wouldn't catch on its own.
func test_character_model_is_not_offset_or_scaled() -> void:
	var wrestler := _make_wrestler()
	var model := wrestler.get_node_or_null("CharacterModel") as Node3D
	assert_vector(model.transform.origin).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.001)
	assert_vector(model.transform.basis.get_scale()).is_equal_approx(
		Vector3.ONE, Vector3.ONE * 0.001
	)
