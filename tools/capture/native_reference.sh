#!/usr/bin/env bash
# Native Mac look captures plus an uncapped-by-Movie-Maker pacing sample.
# Usage: bash tools/capture/native_reference.sh /path/Aegis.app OUTPUT_DIR
set -euo pipefail
app="${1:?usage: native_reference.sh /path/Aegis.app OUTPUT_DIR}"
output="${2:?usage: native_reference.sh /path/Aegis.app OUTPUT_DIR}"
binary="$app/Contents/MacOS/Aegis"
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Run this on the target Mac; cloud software rendering cannot establish Mac performance." >&2
    exit 2
fi
if [[ ! -x "$binary" ]]; then
    echo "Aegis executable not found: $binary" >&2
    exit 2
fi
mkdir -p "$output"
output="$(cd "$output" && pwd)"
# Identify the actual app and host, even when a preview was renamed/copied.
{
    printf 'captured_at_utc: '
    date -u '+%Y-%m-%dT%H:%M:%SZ'
    printf 'architecture: '
    uname -m
    printf 'macos: '
    sw_vers -productVersion
    printf 'chip: '
    sysctl -n machdep.cpu.brand_string
    printf 'memory_bytes: '
    sysctl -n hw.memsize
    shasum -a 256 "$binary"
    for package in "$app"/Contents/Resources/*.pck; do
        [[ ! -f "$package" ]] || shasum -a 256 "$package"
    done
} > "$output/native_environment.txt"
for shot in master corner crowd bodies; do
    "$binary" --windowed --resolution 1920x1080 --fixed-fps 60 \
        res://tools/probe/reference_look.tscn -- --out "$output" --view "$shot" --settle 48 \
        --capture-resolution 1920x1080
done
"$binary" --windowed --resolution 1920x1080 --fixed-fps 60 \
    res://tools/probe/visual_target_proofs.tscn -- --out "$output/entrance_proofs" \
    --capture-resolution 1920x1080 --settle 24
"$binary" --windowed --resolution 1920x1080 --fixed-fps 60 \
    res://tools/probe/visual_target_proofs.tscn -- --studio --portrait-view all \
    --out "$output/character_studies" --capture-resolution 1920x1080 --settle 24
"$binary" --windowed --resolution 1920x1080 \
    res://tools/probe/match_look.tscn -- --out "$output" --frames 1200 --profile \
    --capture-resolution 1920x1080
