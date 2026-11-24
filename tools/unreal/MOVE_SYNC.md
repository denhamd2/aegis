# Move sync while Godot and Unreal overlap

The **Unreal move sync** GitHub Actions workflow builds a move bundle for the
commit it checks out. It verifies authored pair clip names and root paths,
then checks the committed Unreal trajectory snapshot for drift. The workflow
publishes the bundle as an artifact named `aegis-moves-<commit>`. Godot's Mac
release workflow stays independent of the export.

## Publish source updates

Keep the Blender-authored clips and Godot move definitions as the current
source during migration. After changing a root trajectory, regenerate
Godot's paired root library first, then refresh the Unreal snapshot.

```sh
python tools/unreal/move_sync.py --output /tmp/aegis-moves --update-snapshot
python tools/unreal/move_sync.py --output /tmp/aegis-moves --check-snapshot
```

The bundle contains the authored animation GLB, clip mapping, resolved move
definitions, paired timing and grip metadata, and 60 Hz root trajectories.
Its manifest records the source commit, whether relevant source files had
local edits, and the SHA-256 of every payload. The export reads Godot resource
defaults directly. It includes move definitions in both the base and Fight
Forever directories. The Godot step uses a temporary project with no arena
import.

In `move_defs.json`, `paired_rules` is keyed by pair ID. Timing values keep
their source fractions and have corresponding zero-based `_tick` or
`_ticks` fields on the paired trajectory clock. Contact windows include
both endpoints. Grip ticks mark the start or release setting. An engine
that eases out its grip still needs to implement that blend. Contact anchors
use the authored skeleton's bone names and bone-local XYZ offsets in metres.
`move_defs` also contains strike contact offsets in Godot wrestler-local
metres, with -Z forward, strike-hand and reaction enums, and the landing
orientation flags.

For example, Cross Rhodes exports the right-forearm neck hook and left-wrist
contact at ticks 9–18, with wrist assist enabled and release at tick 19.
The running inverted drop exports forearm contact at tick 98, separation
height release at ticks 110–118, and camera impact at tick 118. These values
are inputs for the Unreal implementation. Importing the move tables alone
does not activate those behaviors in Unreal.

## Refresh the Unreal project

1. Download and unpack the workflow artifact for the commit being ported.
2. Reimport its authored animations into the port's existing source rig
   pipeline and rerun retargeting for the supported wrestlers.
3. Set `AEGIS_MOVE_SYNC_BUNDLE` to the unpacked directory and execute
   `import_move_sync.py` in the Unreal editor. The editor Python bridge can also
   pass `SYNC_BUNDLE` and `SOURCE_ANIM_DIR` as script globals.

The editor script verifies payload hashes, checks required source clips
for the staged moves, and verifies the move-to-trajectory
joins before writing the two DataTables. The import receipt records the bundle
commit, hashes, table row counts, and source clip names checked. It confirms
table import and asset presence. Reimport and retargeting still establish the
version of the Unreal animation assets.

Test Snap Dragon 3, Cross Rhodes, Mexican Destroyer, and the running inverted
drop in both wrestler slots. Compare impact and release timing, interruptions,
and the Down transition. Cross Rhodes grip and yaw behavior and the Roman and
Cody running-drop fits still need Unreal equivalents or engine-neutral bakes.
The exported rule fields are available for that work. The current Unreal
DataTable structs consume the existing move and trajectory columns.

## Springboard Cody Cutter

The `dive_springboard_cutter` row resolves to both springboard role clips
under the `aerial` kind. The bundle requires both source assets and exports
the 70-tick startup and 42-tick recovery. The Godot director starts Cody on
the apron 1.30 m from the opponent, starts the defender clip at tick 28,
holds the catch at tick 48 and applies damage at tick 70. Cody's root moves
0.85 m in and 0.42 m to his right. The defender travels 0.34 m inward from
the catch through the bump, then rolls onto his back facing the apron at
the shared Down transition. Check those cases in both slots when porting
the aerial director. [Godot director](../../game/core/match/dive_spot.gd).

## Frog Splash and Springboard Moonsault

The aerial rows require both Blender roles. Frog Splash has a 98-tick
sequence. The root holds at the corner through tick 28, arrives at the
downed opponent at 56, and applies damage at 60 before moving aside for
the cover. The springboard moonsault has a 120-tick sequence and applies
damage at 72 after the opponent has settled onto his back. Port these
director cues with the source clips and validate both slot orders.

After Unreal meets the gameplay, animation, and native M1 acceptance checks,
make Unreal the source for new gameplay. Keep Godot on critical fixes until
retirement and retain the Blender assets and portable move data.
