# MakeHuman adult body-shape source data

These are original MakeHuman `hm08` macro-target assets, released as CC0 1.0.
See their embedded license headers, `../LICENSE.md` and `provenance.json` for
source URLs, GitHub blob IDs and SHA-256 hashes.

The three `*-male-young.target` files are blended equally to establish a generic
adult male anatomical base before locating the source joints. Their catalog
names describe the source asset collection; this blend is not a player-specific
identity or age/rating assertion. Shane's individual likeness and body fit are
separate reference-led adjustments.

The `universal-male-young-averagemuscle-averageweight.target` file is retained as
downloaded source evidence. It contains only comments: the average muscle/weight
setting adds no deltas. The anatomical form comes from the three macro targets.

Targets store indexed XYZ displacements for the licensed `base.obj` mesh. The
Blender foundation tool applies them in memory before joint extraction. A normal
game build and runtime require no network access, MakeHuman installation, or
target-file evaluation.
