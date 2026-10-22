# Football Web retirement — 22 October 2026

The owner no longer needs the Web game. Beechlawn delivery is now universal
macOS only; the separate wrestling Web game remains supported.

- Removed the football Web export preset and platform override.
- The Beechlawn release workflow builds, verifies and publishes only the Mac
  archive. It no longer requests Pages permissions or assembles a shared site.
- Removed the football-preservation step from the wrestling Pages workflow;
  no wrestling game content or export settings changed.
- Removed all 25 `Beechlawn-Rovers-Web.zip` release assets and verified the
  corresponding 25 Mac downloads remain. Archived source references and QA
  evidence remain in Git; they are no longer active Web delivery requirements.
- Requested cancellation of the obsolete queued dual-platform release.
- Added a manual Pages cleanup workflow. It retrieves the exact saved artifact
  for the currently deployed site, removes only `beechlawn-rovers/`, hashes all
  retained wrestling files before/after, then deploys the cleaned artifact.
  Its proof artifact is `beechlawn-web-retirement-proof`. No wrestling rebuild
  or Pages configuration change is used.

Validation: four focused cleanup safety tests pass, covering scope, missing
wrestling files, idempotency, symlinks and an external report location. Workflow
YAML and Mac-only export configuration checks pass. A newly exported Mac-only
bundle passes ZIP integrity, universal arm64/x86_64, bundle identifier and
resource checks without requiring a Web directory. Native M1 execution and
performance remain separate hardware acceptance checks.

Native look checks use `tools/capture_native.py` and
[native_capture_notes.md](native_capture_notes.md); headless checks cover logic.
Hosted removal is verified separately by checking that the old football URL
stops serving a game while the wrestling root remains unchanged. GitHub's
Actions service incident may delay that cleanup deployment.
