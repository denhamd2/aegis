extends GdUnitTestSuite
## The house-emission floor, and the two thresholds it has to sit between.
##
## `ArenaBuilder._house_lit()` solves every non-emissive hall surface for
## `HOUSE_TARGET * reach` linear luminance. That constant is the hall's whole
## contrast, and `gauntlet/refs/lighting.md`'s ablation is why: the twenty-
## fixture house wash contributes nothing measurable to the stands, so the bowl
## is lit by this number and by nothing else.
##
## It is bounded on BOTH sides, and the bounds are different measurements:
##
##   * BELOW by `measure_frame.py`'s void threshold of 0.0025 relative
##     luminance. `VISUAL_BAR.md` bands `void_fraction` at 0.010-0.066, and a
##     surface sitting ON the floor rather than clear of it dithers across it
##     and renders as a speckled void mask -- worse than either side of it.
##     `_house_lit()`'s own comment says so.
##   * ABOVE by `measure_look.py`'s dark threshold of 0.01, which is the number
##     `lighting.md` measures the references at 38-50% against and ours at a
##     tenth of that.
##
## THE GAP BETWEEN THE TWO IS THE WHOLE OPPORTUNITY, and it is a factor of
## four wide. A surface rendering between 0.0025 and 0.01 counts as dark and
## never as void. This suite exists so that the next round to move
## `HOUSE_TARGET` finds out immediately which `reach` it pushed through the
## floor, rather than finding out from a speckled frame.
##
## Renderer-free: it reads constants, not pixels.

## Every table `_house_lit()` is called through, so a new one added without a
## line here is the one gap this suite cannot close on its own.
func _reach_tables() -> Dictionary:
	return {
		"BOWL_MODEL_MATERIALS": ArenaBuilder.BOWL_MODEL_MATERIALS,
		"RINGSIDE_MATERIALS": ArenaBuilder.RINGSIDE_MATERIALS,
		"ENTRANCE_MATERIALS": ArenaBuilder.ENTRANCE_MATERIALS,
	}


## The one that stops a darkening round breaking the frame silently.
func test_no_house_reach_lands_on_the_void_floor() -> void:
	var tables := _reach_tables()
	var checked := 0
	for table_name: String in tables:
		var table: Dictionary = tables[table_name]
		for part: String in table:
			var spec: Array = table[part]
			var product: float = ArenaBuilder.HOUSE_TARGET * float(spec[1])
			checked += 1
			assert_float(product).override_failure_message(
					("%s/%s solves for %.5f linear (HOUSE_TARGET %.4f x reach "
					+ "%.2f). measure_frame.py calls a pixel void below "
					+ "0.0025, and a surface sitting near that floor dithers "
					+ "across it and renders as a SPECKLED void mask rather "
					+ "than as a dark surface. Raise this part's reach to hold "
					+ "its product, or put HOUSE_TARGET back.") % [
						table_name, part, product,
						ArenaBuilder.HOUSE_TARGET, float(spec[1])]
			).is_greater_equal(ArenaBuilder.HOUSE_VOID_MARGIN)
	assert_int(checked).override_failure_message(
			"no reaches were checked -- a table was renamed and this suite is "
			+ "now asserting nothing"
	).is_greater(15)


## The gap-exploit, written down as an assertion rather than as a paragraph.
##
## The upper bound is not 0.01 directly: `measure_look.py` reads RENDERED
## luminance and `HOUSE_TARGET` is a linear emission target, and the pipeline
## between them (filmic tonemap at white 2.0, the saturation grade, glow,
## ambient return) is not the identity. Measured on our own frames, crowd_bank
## renders p50 0.016-0.024 against the seats' solve, which puts the ratio at
## roughly 2.3x.
##
## THAT RATIO IS ONE DATUM AND IS NAMED SO IT CAN BE RE-DERIVED rather than
## inherited. If it is really 1.5x, the ceiling below is too generous and the
## bowl is lighter than this test believes.
const RENDER_RATIO := 2.3


func test_the_house_floor_sits_between_the_two_thresholds() -> void:
	assert_float(ArenaBuilder.HOUSE_TARGET).override_failure_message(
			("HOUSE_TARGET is %.5f, at or under measure_frame.py's 0.0025 void "
			+ "floor before any reach is applied") % ArenaBuilder.HOUSE_TARGET
	).is_greater(0.0025)
	assert_float(ArenaBuilder.HOUSE_TARGET * RENDER_RATIO).override_failure_message(
			("HOUSE_TARGET %.5f renders at about %.4f, at or over "
			+ "measure_look.py's 0.01 dark threshold. The bowl is then a lit "
			+ "surface rather than a dark one, and gauntlet/refs/lighting.md's "
			+ "finding -- a televised arena is 38-50%% below 0.01 and ours is "
			+ "a tenth of that -- has not been addressed.") % [
				ArenaBuilder.HOUSE_TARGET,
				ArenaBuilder.HOUSE_TARGET * RENDER_RATIO]
	).is_less(0.01)


## The hot architecture is the other half of the reference's shape, and it is
## deliberately NOT scaled by HOUSE_TARGET.
##
## `lighting.md`'s second finding is that the bright fraction is small and
## genuinely bright -- 1.5-6.1% of the frame over 0.5, with p99 up at 0.64-0.94
## -- while ours puts more of the frame bright and nothing in it actually hot.
## Shrinking the mid-tones while holding the ribbons, the nosings and the rink
## boards where they are is how that shape is reached. This pins the
## relationship so a later darkening round cannot take the lines with it.
func test_the_lit_architecture_out_ranges_the_house_floor() -> void:
	var brightest_house := 0.0
	for table_name: String in _reach_tables():
		var table: Dictionary = _reach_tables()[table_name]
		for part: String in table:
			brightest_house = maxf(brightest_house,
					ArenaBuilder.HOUSE_TARGET * float(table[part][1]))
	for part: String in ArenaBuilder.BOWL_MODEL_EMISSIVE:
		var level: float = ArenaBuilder.BOWL_MODEL_EMISSIVE[part][1]
		assert_float(level).override_failure_message(
				("%s emits at %.3f against the brightest house-lit surface's "
				+ "%.4f. These are the hall's light LINES -- the ribbon and "
				+ "the stair nosings -- and they stop being lines the moment "
				+ "the surfaces around them catch up.") % [
					part, level, brightest_house]
		).is_greater(brightest_house * 4.0)
