# Surface preview2: continuity and lighting correction

Geometry/groom remain exactly the accepted R7 draft2. Preview1 full albedo, recipe, audit and runtime evidence are retained at ../surface_preview1; the earlier surface_preview directory also remains unchanged.

Replaced Boolean source rectangles with manually traced valid-skin polygons, Gaussian interior distance approximation and a C1 confidence ramp. The source mask excludes hair and outer portrait/background areas. Corrected the live tint math using the actual Godot pixel diagnostic: albedo Color undergoes sRGB conversion, so inverse chroma divides by linear([.73,.65,.59]) then restores each pixel's original luminance. It does not disable tint, change lights or brighten the runtime profile.

Broad source shading is flattened more strongly, referenced to the exposed forehead rather than a shadowed cheek. Stubble retains source high-frequency hairs with a modest12% clean-skin blend outside lips. The pre-existing fallback painted hair / hard nape edge is replaced with clean owned skin using smooth3D scalp, temple and back masks; this must be judged hair-hidden. No old hair is hidden beneath new geometry. Weakly observed lip returns retain their owned lip map. Three texels of atlas padding close tiny-triangle raster pinholes without blurring facial pigment.

The map remains2048x2048, native86.87MB,112499tri/12materials/67bones. Only kenny_head.png and its embedded GLB image changed relative to the geometry draft. Eyes/protected neck/weights/binds unchanged; UV-normal seam audit has0divergences>20deg.

This remains a surface gate with limits: single-source portraits contain directional illumination and have about250px facial width; de-lighting is approximate, profile camera/occlusions are approximate, and skull skin beyond visible areas is a neutral fallback. No completed likeness, groom or performance claim. Actual paired lit/unlit front/quarter/profile decides remaining work.
