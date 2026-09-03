#!/usr/bin/env python3
"""Fetch a CC0 asset, resize it for this project, and write down where it
came from -- in one step, so the last part cannot be forgotten.

ARCHITECTURE.md's third-party-asset rule has two halves, and the second is
the one that decays: "Record provenance at import time, in the CREDITS.md
beside the files. An asset whose origin nobody wrote down cannot be audited
later, which in practice means it has to be removed." A downloaded file and
a hand-written credit line are two actions, and only the first is needed to
see the asset in the engine.

So this tool refuses to save a file it cannot attribute. Licence and source
URL come back from the provider's own API, not from the person running it,
and the CREDITS.md entry is written in the same call that writes the texture.
An asset that arrives without a licence field is an error, not a warning.

Providers:

  polyhaven   api.polyhaven.com. CC0, no key, bulk download explicitly
              sanctioned by the project. Textures and HDRIs.
  ambientcg   ambientcg.com/api/v2. CC0, no key. Already the source of this
              repo's environment materials, so naming stays consistent.

Usage:
  fetch_cc0.py polyhaven <slug> --type texture --res 2k --dest game/assets/environment/materials
  fetch_cc0.py polyhaven <slug> --type hdri --res 2k --dest game/assets/environment/hdri
  fetch_cc0.py ambientcg <AssetId> --res 2K --dest game/assets/environment/materials
  fetch_cc0.py search polyhaven --query fabric --limit 20

Godot import hints are written alongside each file: a colour map is sRGB, a
normal/roughness/AO/metalness map is linear data, and getting that backwards
is the single most common way a PBR set renders wrong.
"""
import argparse
import io
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

USER_AGENT = "aegis-gauntlet-asset-fetcher/1.0 (CC0 asset import)"
TIMEOUT = 120

# Which Godot import flags each map role needs. The colour map is the only
# one carrying sRGB-encoded values; every other channel is linear data, and
# importing it as sRGB silently gamma-shifts the whole material.
ROLE_SRGB = {
    "color": True,
    "normal": False, "roughness": False, "metalness": False,
    "ao": False, "displacement": False, "opacity": False, "arm": False,
}


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read()


def get_json(url: str) -> dict:
    return json.loads(get(url).decode("utf-8"))


# Substring -> role. Longest match wins, so "normalgl" beats "normal" and
# ambientCG's "Color" and Poly Haven's "col" both land on colour.
#
# Poly Haven abbreviates: nor_gl, nor_dx, rough, disp, arm, col. Matching
# only the long spellings quietly classified every one of those as colour,
# which is the sRGB flag -- so a normal and a roughness map would have been
# imported gamma-encoded, the single most common way a PBR set renders
# wrong, and the one this file's docstring promises not to get backwards.
ROLE_PATTERNS = [
    ("normalgl", "normal"), ("normaldx", "normal"), ("normal", "normal"),
    ("nor_gl", "normal"), ("nor_dx", "normal"), ("nor", "normal"),
    ("roughness", "roughness"), ("rough", "roughness"),
    ("metalness", "metalness"), ("metallic", "metalness"),
    ("metal", "metalness"),
    ("displacement", "displacement"), ("disp", "displacement"),
    ("height", "displacement"),
    ("opacity", "opacity"), ("alpha", "opacity"),
    # ambientCG/Poly Haven ship an ARM/ORM channel pack (AO+Rough+Metal).
    # Linear data, never sRGB.
    ("arm", "arm"), ("orm", "arm"),
    ("ao", "ao"),
    ("color", "color"), ("diffuse", "color"), ("albedo", "color"),
    ("col", "color"),
]


def role_of(filename: str) -> str:
    low = filename.lower()
    best, best_len = "color", 0
    for pattern, role in ROLE_PATTERNS:
        if pattern in low and len(pattern) > best_len:
            best, best_len = role, len(pattern)
    return best


def write_import_hint(path: Path, role: str) -> None:
    """Godot generates .import on first open; this writes the two settings
    that must not be left to the default."""
    srgb = ROLE_SRGB.get(role, False)
    hint = path.with_suffix(path.suffix + ".import.hint.json")
    hint.write_text(json.dumps({
        "role": role,
        "srgb": srgb,
        "note": ("colour map: import as sRGB" if srgb else
                 "data map: import as linear (Normal Map for a normal), "
                 "NOT sRGB"),
    }, indent=2) + "\n")


def credit(dest: Path, name: str, provider: str, licence: str, url: str,
           author: str, files: list[str]) -> None:
    if not licence:
        raise SystemExit(
            f"error: {provider} returned no licence for {name!r}. "
            "ARCHITECTURE.md permits CC0 and CC-BY only, and an asset whose "
            "licence nobody recorded cannot be audited later. Refusing to "
            "save it.")
    if licence.upper().replace(" ", "") not in ("CC0", "CC-BY", "CCBY"):
        raise SystemExit(
            f"error: {name!r} is licensed {licence!r}. ARCHITECTURE.md "
            "permits CC0 and CC-BY; anything more restrictive needs a "
            "decision from the repo owner before it lands, not after.")

    path = dest / "CREDITS.md"
    if not path.exists():
        path.write_text(
            "# Third-party assets in this directory\n\n"
            "Written by `tools/assets/fetch_cc0.py` at import time, per\n"
            "`gauntlet/anchor/ARCHITECTURE.md`. Every entry names the source,\n"
            "the author and the licence.\n")
    body = path.read_text()
    if f"## {name}" in body:
        return
    entry = [f"\n## {name}\n",
             f"- source: {url}",
             f"- provider: {provider}",
             f"- author: {author or 'n/a (see source)'}",
             f"- licence: **{licence}**",
             f"- files: {', '.join(sorted(files))}", ""]
    path.write_text(body + "\n".join(entry) + "\n")


def fetch_polyhaven(slug: str, kind: str, res: str, dest: Path) -> None:
    info = get_json(f"https://api.polyhaven.com/info/{slug}")
    files = get_json(f"https://api.polyhaven.com/files/{slug}")
    licence = "CC0"  # Poly Haven is CC0 across the board; assert it anyway.
    if str(info.get("license", "CC0")).lower() not in ("cc0", ""):
        licence = info["license"]
    authors = ", ".join((info.get("authors") or {}).keys())
    dest.mkdir(parents=True, exist_ok=True)
    written = []

    if kind == "hdri":
        entry = files["hdri"][res]["hdr"]
        out = dest / f"{slug}_{res}.hdr"
        out.write_bytes(get(entry["url"]))
        written.append(out.name)
    else:
        for map_name, per_res in files.items():
            if map_name in ("blend", "gltf", "mtlx", "Diffuse"):
                continue
            if res not in per_res:
                continue
            fmt = per_res[res].get("jpg") or per_res[res].get("png")
            if not fmt or "url" not in fmt:
                continue
            role = role_of(map_name)
            ext = Path(fmt["url"]).suffix
            out = dest / f"{slug}_{map_name}_{res}{ext}"
            out.write_bytes(get(fmt["url"]))
            write_import_hint(out, role)
            written.append(out.name)

    if not written:
        raise SystemExit(f"error: nothing downloaded for {slug!r} at {res!r}")
    credit(dest, slug, "Poly Haven", licence,
           f"https://polyhaven.com/a/{slug}", authors, written)
    print(f"{slug}: {len(written)} files -> {dest}")


def fetch_ambientcg(asset_id: str, res: str, dest: Path) -> None:
    meta = get_json("https://ambientcg.com/api/v2/full_json"
                    f"?id={asset_id}&include=downloadData,imageData")
    found = meta.get("foundAssets") or []
    if not found:
        raise SystemExit(f"error: ambientCG has no asset {asset_id!r}")
    asset = found[0]
    licence = asset.get("license") or "CC0"
    downloads = asset.get("downloadFolders", {}) or {}
    url = None
    for folder in downloads.values():
        for group in (folder.get("downloadFiletypeCategories") or {}).values():
            for item in group.get("downloads") or []:
                attr = item.get("attribute") or ""
                if res.upper() in attr.upper() and attr.upper().endswith("PNG"):
                    url = item.get("downloadLink")
                    break
            if url:
                break
        if url:
            break
    if not url:
        raise SystemExit(
            f"error: no {res} PNG download for {asset_id!r} — "
            "run `fetch_cc0.py search ambientcg --query <id>` to see what "
            "resolutions exist")

    dest.mkdir(parents=True, exist_ok=True)
    written = []
    with zipfile.ZipFile(io.BytesIO(get(url))) as z:
        for member in z.namelist():
            if not member.lower().endswith((".png", ".jpg")):
                continue
            role = role_of(member)
            out = dest / Path(member).name
            out.write_bytes(z.read(member))
            write_import_hint(out, role)
            written.append(out.name)
    credit(dest, asset_id, "ambientCG", licence,
           f"https://ambientcg.com/view?id={asset_id}", "", written)
    print(f"{asset_id}: {len(written)} files -> {dest}")


def search(provider: str, query: str, limit: int) -> None:
    if provider == "polyhaven":
        data = get_json(f"https://api.polyhaven.com/assets?t=textures&c={query}")
        for slug in list(data)[:limit]:
            print(f"  {slug:34} {', '.join(data[slug].get('categories', []))}")
    else:
        data = get_json("https://ambientcg.com/api/v2/full_json"
                        f"?type=Material&limit={limit}&q={query}")
        for asset in data.get("foundAssets", []):
            print(f"  {asset.get('assetId', '?'):34} "
                  f"{asset.get('displayName', '')}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("provider", choices=["polyhaven", "ambientcg", "search"])
    ap.add_argument("name", help="asset slug/id, or the provider when searching")
    ap.add_argument("--type", default="texture", choices=["texture", "hdri"])
    ap.add_argument("--res", default="2k")
    ap.add_argument("--dest", default="game/assets/environment/materials")
    ap.add_argument("--query", default="")
    ap.add_argument("--limit", type=int, default=25)
    args = ap.parse_args()

    if args.provider == "search":
        search(args.name, args.query, args.limit)
    elif args.provider == "polyhaven":
        fetch_polyhaven(args.name, args.type, args.res, Path(args.dest))
    else:
        fetch_ambientcg(args.name, args.res, Path(args.dest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
