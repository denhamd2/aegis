# aegis

An original 3D wrestling vertical slice (Godot 4.6, Forward+, Jolt), built
with the Gauntlet Loop pattern — builder/critic rounds judged against a
measured reference corpus.

The game ships fully original wrestlers, movesets, and branding. WWE 2K
footage is used only as a *measurement* reference (frame timings, camera
framing, HUD layout) — no extracted models, textures, audio, or likenesses
enter this repo.

## Layout

- `game/` — the Godot project. Core systems live in `game/core/`
  (`fsm/`, `grapple/`, `combat/`, `minigames/`, `camera/`, `replay/`,
  `capture/`); `game/resources/` holds the `MoveDef` tuning surface;
  `game/tests/` holds gdUnit4 tests.
- `gauntlet/anchor/ARCHITECTURE.md` — the contract gauntlet builders may
  not violate. Read this first.
- `gauntlet/refs/` — the reference corpus: measured timings, camera
  behavior, HUD layout, and feel, all traceable to footage under
  `gauntlet/refs/raw/` (gitignored — drop clips locally).
- `gauntlet/status/` — `slices.json` + the generated
  `gauntlet-status.html` tracking every gauntlet slice's round count,
  verdict, and current largest gap.
- `tools/capture/` — the capture harness driver (`run_capture.sh`), the
  evidence gate (`evidence_gate.py`) that must pass before any critic sees
  a capture, and the status-page generator.

## Current phase

**Phase 0 (anchor infrastructure)** is scaffolded: project skeleton, core
system stubs, replay/determinism plumbing, capture harness, evidence gate,
CI, and the architecture contract.

**Phase 2 (grey-box MVP)** is scaffolded on top of it: `game/scenes/match.tscn`
wires two capsule wrestlers (`wrestler.tscn`), a box ring (`ring.tscn`),
`MatchCamera`, and `MatchReferee` into a playable loop — locomotion, strikes,
tie-up → grapple → move → hit-react/down, pin cover → kickout minigame →
three-count win, and one scripted AI opponent (`WrestlerAI`).

This has been verified against a real Godot 4.6.3-stable binary (headless):
the project imports cleanly, `game/scenes/match.tscn` runs with zero script
errors, and all 7 gdUnit4 tests pass (0 errors, 0 failures, 0 orphans). That
pass caught and fixed several real bugs — untyped-Variant compile errors,
exported `Node`-typed fields silently staying null when assigned via
`NodePath` in a flat `.tscn` (fixed by resolving explicit `NodePath` exports
in `_ready()`), `GrappleRig` never resolving without a paired animation
clip, the grapple move resolver discarding the attacker's chosen move, an
`AI` range-priority bug that meant tie-ups never triggered, and `CombatSystem`
leaking orphan `Node` instances because it extended `Node` with no scene-tree
need (now `RefCounted`). `gdUnit4` v5.0.0 (the tag CI originally pinned)
doesn't compile against Godot 4.6 — CI now pins v6.2.1, confirmed working.

Known Phase 2 gaps, honestly:
- Not played by a human yet — verification above is import + headless
  script-error-free execution + unit tests, not a playtest. Whether the
  match *feels* right (and whether a full match reaches a three-count in
  reasonable time against the AI) is still unconfirmed.
- `GrappleRig` has no paired animation library yet (Phase 3), so it falls
  back to resolving on the move's frame count via a timer instead of an
  `AnimationPlayer` signal — replace once paired clips exist.
- Irish whip, running attacks, reversals, and submissions have FSM states
  and (for submission) a minigame, but aren't yet driven by the referee or
  AI — pin/kickout is the only win-condition path wired end to end.
- Tie-up resolution and pin-kickout timing are placeholder rules (lower
  player index wins tie-up; kickout triggers automatically when the
  marker enters the window, no dedicated input prompt yet).

Still open before the gauntlet (Phase 4) can start:

- **Phase 1** — populate `gauntlet/refs/` from real WWE 2K (or WWF No
  Mercy emulator, as fallback) footage. Currently placeholder/pending.
- **Phase 3** — CC0 asset retargeting + paired grapple/reversal animation
  authoring in Blender.

See `gauntlet/anchor/ARCHITECTURE.md` for the full contract and
`gauntlet/refs/VISUAL_BAR.md` / `FEEL_BAR.md` for the anchor docs each
gauntlet round is judged against.
