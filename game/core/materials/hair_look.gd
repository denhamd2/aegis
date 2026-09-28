class_name HairLook
## Hair that shines like hair (gauntlet/refs/aaa_gap.md, item 7): a highlight
## stretched ACROSS the strands, not a round hot spot.
##
## Each strand is a thin cylinder. Its surface normal swings right round the
## strand but hardly changes along it, so a head of hair is a surface that is
## rough across the strands and smooth along them. That is the band of light
## that runs round a head of hair under a key -- the "halo" 2K26's hair
## update is built on -- and it is GGX anisotropy: roughness stretched along
## one tangent axis. An isotropic material can only draw a round spot, which
## on a hair card reads as plastic.
##
## Godot stretches the highlight along the material's tangent (UV u), or along
## a flowmap's direction when one is given. So the tangent has to run ACROSS
## the strands:
##   * Cody's shells (tools/blender/cody_hair.py): u runs round the head and
##     the strands lie along v -- the tangent is already across them.
##   * Roman's cards: checked on renders (tools/probe/hair_shot.tscn), see
##     RomanModel.HAIR_FLOW.

## GGX anisotropy, -1..1. 0.7 stretches the highlight roughly 3:1 across the
## strands; at 0.9+ it collapses into a hard line that aliases under TAA.
const ANISOTROPY := 0.7


## `across` is the direction ACROSS the strands in UV space; (1, 0) is the
## tangent itself and needs no flowmap.
static func apply(material: BaseMaterial3D, across := Vector2(1.0, 0.0),
		strength := ANISOTROPY) -> void:
	material.anisotropy_enabled = true
	material.anisotropy = strength
	if not across.is_equal_approx(Vector2(1.0, 0.0)):
		material.anisotropy_flowmap = flowmap(across)


## A one-texel flowmap pointing the stretch along `dir` (UV space), encoded as
## the shader reads it: rg = dir * 0.5 + 0.5.
static func flowmap(dir: Vector2) -> ImageTexture:
	var d := dir.normalized()
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(d.x * 0.5 + 0.5, d.y * 0.5 + 0.5, 0.0, 1.0))
	return ImageTexture.create_from_image(image)
