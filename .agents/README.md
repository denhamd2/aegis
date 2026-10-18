# Codex skill discovery

The root `skills/` directory exposes the 38 shared Blender guides through
relative directory symlinks to their canonical `.claude/skills/` folders.
Edit the canonical files; both paths read the same content, including bundled
resources. The `references` alias exposes shared reference documents and is
not itself a skill. The routing table in root `AGENTS.md` defines when to use
each guide and how to adapt MCP-oriented instructions to headless Blender.

## Open the owning project

Codex scans `.agents/skills/` from the working directory up to the repository
root. From the repository root, launch the football project with:

```sh
codex -C games/beechlawn_rovers
```

That discovers both the shared Blender guides and the football project's
six local skills, including `create-player`, `gda` and `grill-me`. Launching
from the repository root discovers the shared guides without automatically
exposing the football-only skills. Keep `create-player` and the other
football guides in `games/beechlawn_rovers/.agents/skills/`; their roster,
kit and gameplay rules belong only to that game. Wrestling-specific skills
such as `import-wrestler` retain the scope defined in root `AGENTS.md`.

In Codex CLI or its IDE extension, use `/skills` or mention `$blender-modeler`
or `$create-player` in a prompt. Skill changes are detected automatically;
if a selector remains stale, restart the Codex session in the owning project.
Starting outside the repository, such as `/workspace`, does not discover
skills in its child checkouts.

## Client boundaries

These repository aliases enable local Codex discovery. They do not install
Blender MCP, add host commands such as `/clear` or `/compact`, or register
skills in ChatGPT's separate composer menu. ChatGPT uses `@` for skills
registered with that host. A client without repository skill discovery can
still follow a guide when given its file path.

[Official skill discovery and invocation documentation](https://developers.openai.com/codex/skills/).
