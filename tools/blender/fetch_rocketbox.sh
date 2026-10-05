#!/usr/bin/env bash
# Fetch the slice of Microsoft Rocketbox the crowd is built from.
#
#   tools/blender/fetch_rocketbox.sh            # into $ROCKETBOX_DIR
#
# Rocketbox (https://github.com/microsoft/Microsoft-Rocketbox, MIT) is several
# GB; the crowd needs twenty avatars' FBX and colour textures and a handful of
# animation clips (~740 MB). This takes a blobless clone pinned to the commit
# rocketbox_crowd.py records and checks out only those files. NOTHING here is
# copied into the repo: the raw FBX/TGA stay in ROCKETBOX_DIR, and only the
# .glb files built from them are committed (see
# game/assets/environment/CREDITS.md).
#
# ROCKETBOX_DIR defaults to the path rocketbox_crowd.py reads.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${ROCKETBOX_DIR:-/tmp/claude-0/rb/repo}"
commit="$(sed -n 's/^ROCKETBOX_COMMIT = "\(.*\)"$/\1/p' "$here/rocketbox_crowd.py")"
avatars="$(python3 - "$here/rocketbox_crowd.py" <<'PY'
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
for node in tree.body:
    if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") in ("AVATARS", "CLIPS"):
        print(node.targets[0].id, " ".join(ast.literal_eval(node.value)))
PY
)"
avatar_list="$(echo "$avatars" | sed -n 's/^AVATARS //p')"
clip_list="$(echo "$avatars" | sed -n 's/^CLIPS //p')"

if [ ! -d "$dir/.git" ]; then
    GIT_LFS_SKIP_SMUDGE=1 git clone --filter=blob:none --no-checkout \
        https://github.com/microsoft/Microsoft-Rocketbox "$dir"
fi
git -C "$dir" fetch --depth 1 --filter=blob:none origin "$commit" 2>/dev/null || true

paths=(LICENSE.md)
for a in $avatar_list; do
    while IFS= read -r p; do paths+=("$p"); done < <(
        git -C "$dir" ls-tree -r --name-only "$commit" "Assets/Avatars/Adults/$a" |
        grep -E "Export/${a}\.fbx$|_color\.tga$")
done
anims="Assets/Animations/all_animations_max_motextr_static"
for c in $clip_list; do
    for g in m f; do paths+=("$anims/${g}_${c}.max.fbx"); done
done
git -C "$dir" checkout "$commit" -- "${paths[@]}"
echo "fetch_rocketbox: ${#paths[@]} files at $commit in $dir"
