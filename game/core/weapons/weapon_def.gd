class_name WeaponDef
extends Resource
## One No Holds Barred weapon (gauntlet/refs/weapons_nhb.md): which model,
## which of its state roots means what, how it is swung, how hard it hits,
## how long it lasts. Built in code by WeaponCatalog, so the whole list is one
## diffable file and nothing is authored in the editor.

## The six families on the weapon wheel's inner ring, in its order.
enum Family { CHAIRS, SWUNG, CARRIED, SET_PIECES, SPRAYS, WHIPS }
const FAMILY_NAMES := ["CHAIRS", "SWUNG", "CARRIED", "SET PIECES", "SPRAYS & GUNS", "WHIPS & FISTS"]

## How it is used when he strikes with it: one clip and one MoveDef each
## (WeaponCatalog.swing_move).
enum Swing { OVERHEAD, SIDE, THRUST, WHIP, PUNCH, CHOP, GUN, LAUNCHER, SPRAY, POUR }

var id: StringName
var display_name := ""
var family: Family = Family.SWUNG
var glb := ""
## State roots in the .glb. `held` is the one in his hands; `dented` and
## `broken` are what wear swaps it to ("" if it has none); `set_up` is the
## state it stands in when he sets it down on purpose (a table up, a ladder
## open, tacks poured).
var held := ""
var dented := ""
var broken := ""
var set_up := ""
## Effect roots: the gun's flash, the extinguisher's cloud, the rocket and
## its blast. Shown by the move, never held.
var effects := {}
var swing: Swing = Swing.SIDE
## Damage per hit, to head and torso, before the swing's own scale.
var damage_head := 0.0
var damage_torso := 0.0
## Hits before it dents (if it can) and before it breaks (if it can). 0: never.
var hits_to_dent := 0
var hits_to_break := 0
var two_handed := false
var throwable := true
## A set piece: a man can be put through it or onto it once it is set up.
var set_piece := false
## Extra damage to a man who lands on it set up (a table, tacks, nails).
var landing_damage := 0.0
## Impact sound family (SfxPool.play_any).
var sound := "hit_metal"
## Wrestler ids who favour it (the AI reaches for these first).
var owners: Array[StringName] = []


func can_dent() -> bool:
	return dented != "" and hits_to_dent > 0


func can_break() -> bool:
	return broken != "" and hits_to_break > 0


func family_name() -> String:
	return FAMILY_NAMES[family]
