"""Build the Unreal port's source rig GLB: the base wrestler plus every authored clip.

    python3 tools/unreal/merge_clips_glb.py [--out PATH]

The port imported its rig once, from wrestler_base_with_clips.glb: the base
wrestler (game/assets/characters/wrestler_base.glb, mesh and 42 CC0 actions)
with the authored wrestling clips added. Every time the clips change
(game/tools/blender/wrestling_clips.py -> game/assets/animations/
wrestling_clips.glb, or a move-sync bundle's copy) this rebuilds that file so
the port reimports it in place, through the same Interchange import, and the
existing AnimSequences update under their own names.

It is a byte-level glTF merge, not a Blender round trip: each clip's
keyframe data is copied unchanged (no resampling, so the 60 fps keys stay
exactly where wrestling_clips.py put them), with channel targets remapped by
node name. Both files share the 65-joint skeleton; the script refuses to run
if they do not. Deterministic: same inputs, byte-identical output.

Default output: ~/Documents/AegisPort/assets/wrestler_base_with_clips.glb,
the path the port's SceneImport asset reimports from.

Order matters: Interchange identifies a glTF animation by its index, so the
merge keeps every clip at the index it had in the file the port last imported
(--order-from, default the existing output) and appends new clips at the end.
Without that, one new clip sorting in early hands every later AnimSequence
its neighbour's motion on reimport.
"""
import argparse
import json
import pathlib
import struct

REPO = pathlib.Path(__file__).resolve().parents[2]
BASE = REPO / "game" / "assets" / "characters" / "wrestler_base.glb"
CLIPS = REPO / "game" / "assets" / "animations" / "wrestling_clips.glb"
OUT = pathlib.Path.home() / "Documents" / "AegisPort" / "assets" / "wrestler_base_with_clips.glb"


def read_glb(path):
    data = path.read_bytes()
    magic, version, _ = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2:
        raise ValueError("not a glTF 2 binary: %s" % path)
    json_len, kind = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + json_len])
    offset = 20 + json_len
    binary = b""
    if offset < len(data):
        bin_len, kind = struct.unpack_from("<I4s", data, offset)
        if kind != b"BIN\0":
            raise ValueError("second chunk is not BIN: %s" % path)
        binary = data[offset + 8:offset + 8 + bin_len]
    return doc, binary


def write_glb(path, doc, binary):
    text = json.dumps(doc, separators=(",", ":"), sort_keys=False).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    out = struct.pack("<4sII", b"glTF", 2, total)
    out += struct.pack("<I4s", len(text), b"JSON") + text
    out += struct.pack("<I4s", len(binary), b"BIN\0") + binary
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)


def joint_names(doc):
    return [doc["nodes"][i]["name"] for i in doc["skins"][0]["joints"]]


def animation_names(path):
    doc, _ = read_glb(path)
    return [a["name"] for a in doc.get("animations", [])]


def merge(base_path, clips_path, order=None):
    base, base_bin = read_glb(base_path)
    clips, clips_bin = read_glb(clips_path)
    if joint_names(base) != joint_names(clips):
        raise ValueError("the base rig and the clips have different skeletons")
    if len(base["buffers"]) != 1 or len(clips["buffers"]) != 1:
        raise ValueError("expected one binary buffer in each file")
    node_by_name = {n["name"]: i for i, n in enumerate(base["nodes"]) if "name" in n}
    authored = {a["name"] for a in clips["animations"]}
    out_bin = bytearray(base_bin + b"\0" * (-len(base_bin) % 4))
    # A base action of the same name as an authored clip is replaced by it.
    base["animations"] = [a for a in base.get("animations", []) if a["name"] not in authored]
    accessor_map = {}

    def copy_accessor(index):
        if index in accessor_map:
            return accessor_map[index]
        acc = dict(clips["accessors"][index])
        view = dict(clips["bufferViews"][acc["bufferView"]])
        start = view.get("byteOffset", 0)
        chunk = clips_bin[start:start + view["byteLength"]]
        out_bin.extend(b"\0" * (-len(out_bin) % 4))
        view["byteOffset"] = len(out_bin)
        view["buffer"] = 0
        out_bin.extend(chunk)
        base["bufferViews"].append(view)
        acc["bufferView"] = len(base["bufferViews"]) - 1
        base["accessors"].append(acc)
        accessor_map[index] = len(base["accessors"]) - 1
        return accessor_map[index]

    ordered = clips["animations"]
    if order:
        # Keep every clip where the port's last import had it: Interchange keys
        # a glTF animation by its INDEX, so a clip that moves (a new one sorting
        # in ahead of it) is reimported with another clip's motion under its
        # name. Clips new since then go at the end, in name order.
        rank = {name: i for i, name in enumerate(order)}
        ordered = sorted(clips["animations"], key=lambda a: (a["name"] not in rank, rank.get(a["name"], 0), a["name"]))
        lost = [n for n in order if n not in authored and n not in {a["name"] for a in base["animations"]}]
        if lost:
            raise ValueError("clips the port has but the new file lacks (would shift indices): %s" % lost)
    for anim in ordered:
        samplers =[dict(s, input=copy_accessor(s["input"]), output=copy_accessor(s["output"]))
                    for s in anim["samplers"]]
        channels = []
        for ch in anim["channels"]:
            name = clips["nodes"][ch["target"]["node"]]["name"]
            if name not in node_by_name:
                raise ValueError("%s animates %r, which the base rig does not have" % (anim["name"], name))
            channels.append({"sampler": ch["sampler"],
                             "target": dict(ch["target"], node=node_by_name[name])})
        base["animations"].append({"name": anim["name"], "channels": channels, "samplers": samplers})
    out_bin.extend(b"\0" * (-len(out_bin) % 4))
    base["buffers"][0]["byteLength"] = len(out_bin)
    return base, bytes(out_bin)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", type=pathlib.Path, default=BASE)
    ap.add_argument("--clips", type=pathlib.Path, default=CLIPS)
    ap.add_argument("--out", type=pathlib.Path, default=OUT)
    ap.add_argument("--order-from", type=pathlib.Path, default=None,
                    help="the GLB the port last imported (default: --out, if it exists)")
    a = ap.parse_args()
    ref = a.order_from or (a.out if a.out.exists() else None)
    order = animation_names(ref) if ref else None
    doc, binary = merge(a.base, a.clips, order)
    if order and [x["name"] for x in doc["animations"]][:len(order)] != order:
        raise ValueError("merged order does not keep %s's indices" % ref)
    write_glb(a.out, doc, binary)
    print("%s: %d animations, %.1f MB" % (a.out, len(doc["animations"]), a.out.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
