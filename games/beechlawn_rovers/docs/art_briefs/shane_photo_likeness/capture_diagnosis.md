# Software screenshot timeout diagnosis

Reproduction: the actual new head review reached `SHANE_ASSET_REVIEW_READY`, then
`capture_beechlawn_web.py` failed at `Page.screenshot` after 30 seconds. A full
release-menu/match browser check also exceeded its outer 150-second deadline.
These are capture failures, not successful screenshots or native performance data.

Ranked checks: continuous rendering/readback, alpha-hair shadow cost, then browser
contention. Inspection found two concrete mode gaps: the match's software shadow,
frame-cap and freeze controls are guarded by Web **and debug**, while the attempted
full check used a release export; the isolated head-review scene never installed a
freeze hook at all. The larger groom increased render cost enough to expose it.

The isolated debug review now installs the existing capture callback pattern,
limits software capture rendering and omits software sun shadows. Its source and
release gameplay lights remain unchanged. The browser checker supports release
menu-only evidence and requires a debug freeze callback for full software match
checks, with a smaller match viewport after full-size menu captures. This changes
neither the actor count nor authoritative simulation. It does not increase the
screenshot timeout or treat asset counts as an FPS measurement.

Regression evidence: fresh `godot_portrait.png` / `godot_threequarter.png` from
the real production appearance path, release `title_photoreal_evidence/` menu
captures and separate `title_photoreal_evidence/debug_match/` mode checks. Native
Mac rendering and sustained M1 timing remain unverified.
