# Official Codex guidance and local measurements

Checked 7 November 2026. These are sourced workflow recommendations, not
measurements of this game or evidence of faster tests.

- [Official best practices](https://learn.chatgpt.com/docs/learn/best-practices):
  use concise `AGENTS.md` guidance for repository conventions, concrete
  verification commands and completion criteria. Put detailed plans in linked
  documents. Start GPT-6.1 Sol at the client's default reasoning effort and
  adjust using observed results. No configuration change was made here.
- [GPT-6.1 Sol model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol):
  documents the model and its API controls; it does not establish a preferred
  Godot test strategy or any Aegis performance result.

Local practice follows the owner's plan: inspect only relevant files, batch
independent reads, keep a concise release ledger, use the least expensive
adequate validation, and work without sub-agents. Release 7 must measure suite
and fixture costs before claiming an optimisation. No suite-speed or M1
frame-time improvement has been measured in this restoration pass.
