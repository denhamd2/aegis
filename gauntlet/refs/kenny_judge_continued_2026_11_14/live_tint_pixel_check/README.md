# Live tint pixel check

Godot 4.6.3, actual Forward+ Vulkan llvmpipe, isolated unshaded quads.
Run using a working display with the CLI renderer override:
`godot --path <this-folder> --rendering-method forward_plus --rendering-driver vulkan -s check.gd`.
The temporary diagnostic writes /tmp/kenny-tint-check/actual.png.

Measured RGB: plain tint (.7294,.6510,.5882); .5 texture × tint
(.3569,.3137,.2824); plain .5 control (.4980,.4980,.4980).
This confirms the effective multiplier is srgb_to_linear(.73,.65,.59), not the
raw numeric tint. The authoring compensation must operate in that same linear
space. Normalize to the original per-pixel luminance to isolate chroma rather
than brighten the reference. This is a colour-pipeline diagnostic, not a native
M1 performance test or a likeness score.
