extends Node
## PairClearance over just the chain-wrestling links (Phase 4), with the hand
## grip median, for tuning them without the whole paired suite.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/chain_lint.tscn

func _ready() -> void:
	for id in ["chain_headlock", "chain_wristlock", "chain_waistlock"]:
		var r: Dictionary = await PairClearance.measure(self, id)
		var grip: Array = r["grip"]
		grip.sort()
		var med: float = grip[grip.size() / 2] if not grip.is_empty() else -1.0
		print("CHAIN %-16s body %.3f arm %.3f grip %.3f  %s @%.2f" % [id, r["body"], r["arm"], med, r["where"], r["at"]])
	get_tree().quit()
