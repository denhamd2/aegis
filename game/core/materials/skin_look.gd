class_name SkinLook
## What makes a wrestler's skin read as flesh rather than painted plastic
## (gauntlet/refs/aaa_gap.md, item 2): light going INTO the skin and
## scattering before it comes back out.
##
## Without it a skin material is a hard Lambert surface: the terminator where
## the key light falls off is a sharp line, and a backlit ear is as dark as a
## shoulder. Real skin softens that line with a warm bleed -- the light that
## went in under the lit side and came out a few millimetres into the shadow --
## and glows red where it is thin enough to light through. Both are what 2K's
## faces do under a truss key, and both are one BaseMaterial3D feature,
## screen-space subsurface scattering in skin mode.
##
## Applied by each character model to the materials it already identifies as
## skin (RomanModel.SKIN_ROUGHNESS, CodyModel.SKIN_MATERIALS), on the
## duplicates it already makes -- never to gear, hair or eyes. Not to Kenny:
## his scan is ONE material over skin and gear alike, and scattering light
## through his vest would read as wet cloth.

## How far light spreads under the surface, as the renderer's 0-1 strength.
## 0.45: enough that the terminator on a bicep softens by a finger's width at
## the match camera, not so much that a face goes waxy in a close-up.
const STRENGTH := 0.45
## Thin parts lit from behind -- ears, fingers, the rim of a nose -- pass a
## little red light: blood under skin. Depth is how thick a part can be and
## still pass it; boost stays 0 so a whole torso never glows.
const TRANSMITTANCE_COLOR := Color(0.85, 0.30, 0.20)
const TRANSMITTANCE_DEPTH := 0.06


static func apply(material: BaseMaterial3D) -> void:
	material.subsurf_scatter_enabled = true
	material.subsurf_scatter_skin_mode = true
	material.subsurf_scatter_strength = STRENGTH
	material.subsurf_scatter_transmittance_enabled = true
	material.subsurf_scatter_transmittance_color = TRANSMITTANCE_COLOR
	material.subsurf_scatter_transmittance_depth = TRANSMITTANCE_DEPTH
	material.subsurf_scatter_transmittance_boost = 0.0
