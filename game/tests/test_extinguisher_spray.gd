extends GdUnitTestSuite
## The fire extinguisher's discharge (the owner, 2 Nov: "The fire
## extinguisher smoke looks like a polygonal cloud, rather than smoke
## particles, fix it"). The cloud mesh stays hidden; soft particle puffs go
## out along the horn's +Z, once, and the effect frees itself after them.


func test_the_discharge_is_particles_not_the_cloud_mesh() -> void:
	var def := WeaponCatalog.by_id(&"fire_extinguisher")
	var gun: WeaponActor = auto_free(WeaponActor.make(def))
	add_child(gun)
	var e := gun._spawn_effect(self, "cloud", Transform3D(Basis(), Vector3(0, 1, 0)))
	assert_object(e).is_not_null()
	assert_bool(e._model.visible).is_false()
	var puffs := e.get_node_or_null("Puffs") as GPUParticles3D
	assert_object(puffs).is_not_null()
	assert_bool(puffs.one_shot).is_true()
	assert_bool(puffs.emitting).is_true()
	var m := puffs.process_material as ParticleProcessMaterial
	assert_vector(m.direction).is_equal(Vector3(0, 0, 1))
	# soft round sprites, not the faceted mesh
	var quad := puffs.draw_pass_1 as QuadMesh
	assert_object(quad).is_not_null()
	assert_int((quad.material as StandardMaterial3D).billboard_mode) \
			.is_equal(BaseMaterial3D.BILLBOARD_PARTICLES)
	# the effect outlives its puffs, then goes
	assert_float(WeaponActor.EFFECT_LIFE["cloud"]).is_greater_equal(WeaponActor.CLOUD_PUFF_LIFE)
	assert_float(e.scale.x).is_equal_approx(1.0, 0.001)
	e.queue_free()
