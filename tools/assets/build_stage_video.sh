#!/usr/bin/env bash
# Transcodes the entrance-set clip into the two files the video wall needs.
#
# Godot cannot play MP4 -- its built-in video backend is Ogg Theora and
# nothing else -- so the supplied clip has to be converted before it can go
# anywhere near a VideoStreamPlayer. This script is that conversion, kept in
# the repo rather than run once by hand so the committed assets can be
# reproduced from the source at any point.
#
# Usage:
#   tools/assets/build_stage_video.sh <source.mp4>
#
# Outputs (both committed):
#   game/assets/environment/video/dynamite_tron.ogv
#   game/assets/environment/video/dynamite_tron_still.png
set -euo pipefail

SOURCE="${1:?usage: build_stage_video.sh <source video>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$REPO_ROOT/game/assets/environment/video"

# Quality 4, measured: q7 encodes the supplied 78s clip at 53MB and q4 at
# 23MB with no difference this wall can show. The wall is 18m of geometry
# seen from 28m away through a bloom threshold -- it is not where a bitrate
# is worth spending.
QUALITY="${THEORA_QUALITY:-4}"

# No audio track. Not tidiness: an audio track would need a bus and an
# AudioStreamPlayer, and audio timing is one more thing that differs between
# a capture and a play session.
mkdir -p "$OUT_DIR"
ffmpeg -y -i "$SOURCE" -c:v libtheora -q:v "$QUALITY" -an \
    "$OUT_DIR/dynamite_tron.ogv"

# One frame, at 3s, where the logo is fully formed. Two jobs, and it is one
# asset because they are the same requirement seen twice: it is what a
# frame-locked capture renders (see core/arena/stage_video.gd) and what the
# wall falls back to when the clip cannot be decoded.
ffmpeg -y -ss 3 -i "$SOURCE" -frames:v 1 \
    "$OUT_DIR/dynamite_tron_still.png"

ls -la "$OUT_DIR"
