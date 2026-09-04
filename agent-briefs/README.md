# Agent briefs

Long-form **personas, prompts, and templates** for Workday Recruiting PM work. Cursor does not load these automatically; use them when starting a chat, or fold excerpts into `.cursor/rules/*.mdc` or `.cursor/skills/*/SKILL.md`.

## How this fits together

| Location | Purpose |
|----------|---------|
| [`.cursor/skills/`](../.cursor/skills/) | Step-by-step workflows the agent should follow when you @-mention or attach a skill. |
| [`.cursor/rules/`](../.cursor/rules/) | Short, always-on or pickable constraints and context (`.mdc`). |
| `agent-briefs/` (here) | Deeper “sub-agent” briefs: voice, examples, and long templates. |

## Personal vs project skills

- **Project** (this repo): `.cursor/skills/<skill-name>/`.
- **Personal** (all repos on your machine): `~/.cursor/skills/<skill-name>/` — copy a skill folder there if you want it everywhere. Do not use `~/.cursor/skills-cursor/` (Cursor reserved).

## Files in this folder

- [`stakeholder-memo.md`](stakeholder-memo.md) — memo-oriented sub-agent.
- [`exec-summary-release.md`](exec-summary-release.md) — release exec summary example.
