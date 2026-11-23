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

## Refresh the Unreal project

1. Download and unpack the workflow artifact for the commit being ported.
2. Reimport its authored animations into the port's existing source rig
   pipeline and rerun retargeting for the supported wrestlers.
3. Set `AEGIS_MOVE_SYNC_BUNDLE` to the unpacked directory and execute
   `import_move_sync.py` in the Unreal editor. The editor Python bridge can also
   pass `SYNC_BUNDLE` and `SOURCE_ANIM_DIR` as script globals.

The editor script verifies payload hashes, checks that the eight source
clips for the initial four moves exist, and verifies the move-to-trajectory
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

After Unreal meets the gameplay, animation, and native M1 acceptance checks,
make Unreal the source for new gameplay. Keep Godot on critical fixes until
retirement and retain the Blender assets and portable move data.
